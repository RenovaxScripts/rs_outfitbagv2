const app = document.getElementById('app');
const backdrop = document.getElementById('backdrop');
const jobsContainer = document.getElementById('jobs');
const emptyState = document.getElementById('empty-state');
const confirmLayer = document.getElementById('confirm');
const searchInput = document.getElementById('search-input');
const clearSearchBtn = document.getElementById('clear-search');
const slotProgress = document.getElementById('slot-progress');
const jobCountEl = document.getElementById('job-count');

const state = {
    jobs: [],
    filteredJobs: [],
    maxJobs: 0,
    allowRemove: false,
    defaultJob: '',
    showSalary: true,
    salaryFormat: '$%s',
    enableDuty: true,
    offDutyPrefix: 'off_',
    jobIcons: {},
    selectedJob: null,
    locale: {},
    pendingRemoval: null,
    closeTimer: null,
    searchQuery: ''
};

const refreshLucideIcons = () => {
    if (typeof lucide !== 'undefined' && lucide.createIcons) {
        lucide.createIcons();
    }
};

const getJobIconHtml = (jobName = '') => {
    const rawName = String(jobName).toLowerCase();
    const cleanName = rawName.startsWith(state.offDutyPrefix) ? rawName.slice(state.offDutyPrefix.length) : rawName;

    if (state.jobIcons && (state.jobIcons[cleanName] || state.jobIcons[rawName])) {
        const iconClass = state.jobIcons[cleanName] || state.jobIcons[rawName];
        if (iconClass.startsWith('fa-') || iconClass.includes(' ')) {
            return `<i class="${iconClass}"></i>`;
        }
        if (iconClass.startsWith('lucide-')) {
            return `<i data-lucide="${iconClass.replace('lucide-', '')}"></i>`;
        }
        return `<i data-lucide="${iconClass}"></i>`;
    }

    if (cleanName.includes('police') || cleanName.includes('sheriff') || cleanName.includes('cop') || cleanName.includes('lspd')) {
        return `<i data-lucide="shield-check"></i>`;
    }
    if (cleanName.includes('ambulance') || cleanName.includes('ems') || cleanName.includes('doctor') || cleanName.includes('medic') || cleanName.includes('hospital')) {
        return `<i data-lucide="heart-pulse"></i>`;
    }
    if (cleanName.includes('mechanic') || cleanName.includes('custom') || cleanName.includes('tuning') || cleanName.includes('repair') || cleanName.includes('auto')) {
        return `<i data-lucide="wrench"></i>`;
    }
    if (cleanName.includes('taxi') || cleanName.includes('cab') || cleanName.includes('driver')) {
        return `<i data-lucide="car"></i>`;
    }
    if (cleanName.includes('cardealer') || cleanName.includes('dealer') || cleanName.includes('pdm') || cleanName.includes('car')) {
        return `<i data-lucide="badge-dollar-sign"></i>`;
    }
    if (cleanName.includes('realestate') || cleanName.includes('agent') || cleanName.includes('house')) {
        return `<i data-lucide="building-2"></i>`;
    }
    if (cleanName.includes('mafia') || cleanName.includes('gang') || cleanName.includes('cartel') || cleanName.includes('biker')) {
        return `<i data-lucide="skull"></i>`;
    }
    if (cleanName.includes('unemployed') || cleanName.includes('card') || cleanName.includes('none')) {
        return `<i data-lucide="user-x"></i>`;
    }
    if (cleanName.includes('reporter') || cleanName.includes('news') || cleanName.includes('media')) {
        return `<i data-lucide="newspaper"></i>`;
    }
    if (cleanName.includes('lawyer') || cleanName.includes('judge')) {
        return `<i data-lucide="scale"></i>`;
    }
    if (cleanName.includes('garbage') || cleanName.includes('trash')) {
        return `<i data-lucide="trash-2"></i>`;
    }

    return `<i data-lucide="briefcase"></i>`;
};

const post = (endpoint, data = {}) => fetch(`https://${GetParentResourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
}).catch(() => null);

const translate = (key, replacements = {}) => {
    let value = state.locale[key] || key;
    Object.entries(replacements).forEach(([name, replacement]) => {
        value = value.replaceAll(`{${name}}`, String(replacement));
    });
    return value;
};

const formatSalary = (amount = 0) => {
    const formattedAmount = Number(amount || 0).toLocaleString();
    return String(state.salaryFormat || '$%s').replace('%s', formattedAmount);
};

const setStaticText = () => {
    document.getElementById('menu-title').textContent = translate('ui_title');
    document.getElementById('menu-subtitle').textContent = translate('ui_subtitle');
    const slotLabelEl = document.getElementById('slot-label');
    if (slotLabelEl) slotLabelEl.textContent = translate('ui_slots_occupied');
    document.getElementById('empty-title').textContent = translate('ui_empty_title');
    document.getElementById('empty-text').textContent = translate('ui_empty_text');
    document.getElementById('close-hint').textContent = translate('ui_close');
    document.getElementById('close-button').setAttribute('aria-label', translate('ui_close'));
    if (clearSearchBtn) clearSearchBtn.setAttribute('aria-label', translate('ui_clear'));
    document.getElementById('confirm-title').textContent = translate('ui_confirm_title');
    document.getElementById('cancel-remove').textContent = translate('ui_cancel');
    document.getElementById('confirm-remove').textContent = translate('ui_confirm_remove');
    searchInput.placeholder = translate('ui_search_placeholder');
};

const makeElement = (tag, className, text) => {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
};

const filterJobs = () => {
    const query = state.searchQuery.trim().toLowerCase();
    if (!query) {
        state.filteredJobs = [...state.jobs];
    } else {
        state.filteredJobs = state.jobs.filter((job) =>
            job.label.toLowerCase().includes(query) ||
            job.name.toLowerCase().includes(query) ||
            job.gradeLabel.toLowerCase().includes(query)
        );
    }
};

const showConfirmation = (job) => {
    state.pendingRemoval = job;
    document.getElementById('confirm-text').textContent = translate('ui_confirm_text', { job: job.label });
    confirmLayer.classList.remove('is-hidden');
    confirmLayer.setAttribute('aria-hidden', 'false');
    document.getElementById('cancel-remove').focus();
    refreshLucideIcons();
};

const hideConfirmation = () => {
    state.pendingRemoval = null;
    document.getElementById('confirm-remove').disabled = false;
    confirmLayer.classList.add('is-hidden');
    confirmLayer.setAttribute('aria-hidden', 'true');
};

const renderJobs = () => {
    filterJobs();
    jobsContainer.replaceChildren();

    const totalCount = state.jobs.length;
    const max = state.maxJobs;
    jobCountEl.textContent = translate('ui_jobs_count', { count: totalCount, max: max });

    const progressPercent = max > 0 ? Math.min(100, Math.round((totalCount / max) * 100)) : 0;
    slotProgress.style.width = `${progressPercent}%`;

    const hasJobs = state.filteredJobs.length > 0;
    jobsContainer.classList.toggle('is-hidden', !hasJobs);
    emptyState.classList.toggle('is-hidden', hasJobs);

    state.filteredJobs.forEach((job) => {
        const isSelected = state.selectedJob === job.name;
        const isActive = job.active === true;
        const isOnDuty = job.onDuty !== false;

        const cardClasses = ['job-card'];
        if (isSelected) cardClasses.push('is-selected');
        if (isActive) cardClasses.push('is-active-job');
        if (isActive && !isOnDuty) cardClasses.push('is-off-duty');

        const card = makeElement('article', cardClasses.join(' '));
        card.tabIndex = 0;
        card.setAttribute('aria-label', job.label);

        const selectCard = () => {
            if (state.selectedJob === job.name) return;
            state.selectedJob = job.name;
            renderJobs();
        };

        card.addEventListener('click', selectCard);

        const summary = makeElement('div', 'job-summary');
        const iconWrap = makeElement('div', 'job-icon-wrap');
        iconWrap.innerHTML = getJobIconHtml(job.name);

        const primary = makeElement('div', 'job-primary');
        const titleRow = makeElement('div', 'job-title-row');
        titleRow.append(makeElement('h2', '', job.label));

        const statusPillClass = `status-pill${isActive ? (isOnDuty ? ' is-active' : ' is-off-duty') : ''}`;
        const statusPill = makeElement('span', statusPillClass);
        const statusTextKey = isActive ? (isOnDuty ? 'ui_active' : 'ui_off_duty') : 'ui_inactive';
        statusPill.append(
            makeElement('span', 'status-dot'),
            document.createTextNode(translate(statusTextKey))
        );
        titleRow.append(statusPill);

        const subtitle = makeElement('div', 'job-subtitle');
        const gradeText = `${job.gradeLabel} (${job.grade})`;
        subtitle.append(makeElement('span', 'job-grade-label', gradeText));

        if (state.showSalary && job.salary !== undefined) {
            const salaryText = `${formatSalary(job.salary)} ${translate('ui_payday')}`;
            subtitle.append(makeElement('span', 'job-salary-badge', salaryText));
        }

        primary.append(titleRow, subtitle);
        summary.append(iconWrap, primary);
        card.append(summary);

        if (isSelected) {
            const details = makeElement('div', 'job-details');
            const actions = makeElement('div', 'job-actions');

            if (isActive && state.enableDuty && job.name !== state.defaultJob) {
                const dutyButton = makeElement('button', 'button button-secondary', translate('ui_toggle_duty'));
                dutyButton.type = 'button';
                dutyButton.addEventListener('click', (event) => {
                    event.stopPropagation();
                    dutyButton.disabled = true;
                    post('toggleDuty');
                });
                actions.append(dutyButton);
            } else {
                const activateButton = makeElement(
                    'button',
                    'button button-primary',
                    translate(isActive ? 'ui_active_button' : 'ui_activate')
                );
                activateButton.type = 'button';
                activateButton.disabled = isActive;

                activateButton.addEventListener('click', (event) => {
                    event.stopPropagation();
                    if (isActive) return;
                    activateButton.disabled = true;
                    post('activate', { job: job.name });
                });
                actions.append(activateButton);
            }

            if (state.allowRemove && job.name !== state.defaultJob) {
                const removeButton = makeElement('button', 'button button-danger-subtle', translate('ui_remove'));
                removeButton.type = 'button';
                removeButton.addEventListener('click', (event) => {
                    event.stopPropagation();
                    showConfirmation(job);
                });
                actions.append(removeButton);
            } else {
                actions.classList.add('single-action');
            }

            details.append(actions);
            card.append(details);
        }

        jobsContainer.append(card);
    });

    refreshLucideIcons();
};

const applyPayload = (payload = {}) => {
    state.jobs = Array.isArray(payload.jobs) ? payload.jobs : [];
    state.maxJobs = Number(payload.maxJobs) || 0;
    state.allowRemove = payload.allowRemove === true;
    state.defaultJob = typeof payload.defaultJob === 'string' ? payload.defaultJob : '';
    state.showSalary = payload.showSalary !== false;
    state.salaryFormat = payload.salaryFormat || '$%s';
    state.enableDuty = payload.enableDuty === true;
    state.offDutyPrefix = payload.offDutyPrefix || 'off_';
    state.jobIcons = payload.jobIcons && typeof payload.jobIcons === 'object' ? payload.jobIcons : {};
    state.locale = payload.locale && typeof payload.locale === 'object' ? payload.locale : {};

    if (!state.jobs.some((job) => job.name === state.selectedJob)) {
        const activeJob = state.jobs.find((job) => job.active);
        state.selectedJob = activeJob ? activeJob.name : (state.jobs[0]?.name || null);
    }

    hideConfirmation();
    setStaticText();
    renderJobs();
};

const openMenu = (payload) => {
    if (state.closeTimer) {
        clearTimeout(state.closeTimer);
        state.closeTimer = null;
    }

    state.searchQuery = '';
    searchInput.value = '';
    clearSearchBtn.classList.add('is-hidden');

    applyPayload(payload);

    document.body.classList.remove('nui-hidden');
    app.classList.remove('is-hidden');
    app.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => app.classList.add('is-visible'));
    refreshLucideIcons();
};

const closeMenu = (notifyGame = true, immediate = false) => {
    if (state.closeTimer) clearTimeout(state.closeTimer);

    hideConfirmation();
    app.classList.remove('is-visible');
    app.setAttribute('aria-hidden', 'true');

    const finishClose = () => {
        app.classList.add('is-hidden');
        document.body.classList.add('nui-hidden');
        state.closeTimer = null;
    };

    if (immediate) {
        finishClose();
    } else {
        state.closeTimer = setTimeout(finishClose, 200);
    }

    if (notifyGame) post('close');
};

searchInput.addEventListener('input', (e) => {
    state.searchQuery = e.target.value;
    clearSearchBtn.classList.toggle('is-hidden', !state.searchQuery);
    renderJobs();
});

clearSearchBtn.addEventListener('click', () => {
    state.searchQuery = '';
    searchInput.value = '';
    clearSearchBtn.classList.add('is-hidden');
    renderJobs();
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') openMenu(data.payload);
    if (data.action === 'update') applyPayload(data.payload);
    if (data.action === 'close') closeMenu(false, data.immediate === true);
});

document.getElementById('close-button').addEventListener('click', () => closeMenu());
backdrop.addEventListener('click', () => closeMenu());
document.getElementById('cancel-remove').addEventListener('click', hideConfirmation);
document.getElementById('confirm-remove').addEventListener('click', () => {
    if (!state.pendingRemoval) return;
    const jobName = state.pendingRemoval.name;
    document.getElementById('confirm-remove').disabled = true;
    post('remove', { job: jobName });
    hideConfirmation();
});

confirmLayer.addEventListener('click', (event) => {
    if (event.target === confirmLayer) hideConfirmation();
});

document.addEventListener('keydown', (event) => {
    if (app.classList.contains('is-hidden')) return;

    if (event.key === 'Escape') {
        if (!confirmLayer.classList.contains('is-hidden')) {
            hideConfirmation();
            return;
        }
        closeMenu();
    }
});
