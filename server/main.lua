local playerCache = {}
local switchCooldowns = {}
local actionLocks = {}
local playerDutyState = {}
local resourceReady = false

local function notify(sourceId, message, notifyType)
    sourceId = tonumber(sourceId) or 0
    if sourceId == 0 then
        print(('[rs_multijob] %s'):format(message))
        return
    end

    TriggerClientEvent('rs_multijob:client:notify', sourceId, message, notifyType or 'info')
end

local function sendChat(sourceId, message, color)
    sourceId = tonumber(sourceId) or 0
    if sourceId == 0 then
        print(('[rs_multijob] %s'):format(message))
        return
    end

    TriggerClientEvent('chat:addMessage', sourceId, {
        color = color or { 129, 140, 248 },
        args = { 'Multijob', message }
    })
end

local function normalizeJobName(jobName)
    if type(jobName) ~= 'string' then return nil end
    jobName = jobName:lower()

    if #jobName < 1 or #jobName > 64 or not jobName:match('^[%w_-]+$') then
        return nil
    end

    return jobName
end

local function collectionContains(collection, jobName)
    if type(collection) ~= 'table' then return false end
    if collection[jobName] == true then return true end

    for _, value in ipairs(collection) do
        if tostring(value):lower() == jobName then return true end
    end

    return false
end

local function isJobAllowed(jobName)
    if collectionContains(Config.BlacklistJobs, jobName) then return false end

    if type(Config.WhitelistJobs) == 'table' and next(Config.WhitelistJobs) ~= nil then
        return collectionContains(Config.WhitelistJobs, jobName)
    end

    return true
end

local function getCachedJobs(sourceId, forceRefresh)
    local identifier = Framework.GetIdentifier(sourceId)
    if not identifier then return nil, nil end

    local cached = playerCache[sourceId]
    if not forceRefresh and cached and cached.identifier == identifier then
        return cached.jobs, identifier
    end

    local rows = Database.GetJobs(identifier)
    local jobs = {}

    for _, row in ipairs(rows or {}) do
        jobs[#jobs + 1] = {
            name = tostring(row.job_name),
            label = tostring(row.job_label or row.job_name),
            grade = tonumber(row.grade) or 0,
            gradeLabel = tostring(row.grade_label or row.grade),
            createdAt = row.created_at
        }
    end

    playerCache[sourceId] = {
        identifier = identifier,
        jobs = jobs
    }

    return jobs, identifier
end

local function findStoredJob(jobs, jobName)
    for index, job in ipairs(jobs or {}) do
        if job.name == jobName then
            return job, index
        end
    end

    return nil, nil
end

local function ensureReady(sourceId)
    sourceId = tonumber(sourceId)
    if not sourceId or sourceId <= 0 then return false end

    if not Framework.ready then
        notify(sourceId, _L('framework_not_ready'), 'error')
        return false
    end

    if not Database.ready then
        notify(sourceId, _L('database_not_ready'), 'error')
        return false
    end

    if not Framework.GetPlayer(sourceId) then
        return false
    end

    return true
end

local ensureDefaultJob

local function addPlayerJob(sourceId, jobName, grade, options)
    options = options or {}
    if not ensureReady(sourceId) then return false, 'not_ready' end

    jobName = normalizeJobName(jobName)
    if not jobName then return false, 'invalid_job' end

    local defaultJobName = normalizeJobName(Config.DefaultJob)
    local isDefaultJob = jobName == defaultJobName
    if not options.skipDefault and jobName ~= defaultJobName then
        if not ensureDefaultJob(sourceId) then
            if options.notify ~= false then notify(sourceId, _L('default_job_invalid'), 'error') end
            return false, 'default_job_invalid'
        end
    end

    local canonicalJob, validationError = Framework.GetJob(jobName, grade)
    if not canonicalJob then
        if options.notify ~= false then notify(sourceId, _L(validationError), 'error') end
        return false, validationError
    end

    if not isDefaultJob and not options.bypassFilters and not isJobAllowed(jobName) then
        if options.notify ~= false then notify(sourceId, _L('job_not_allowed'), 'error') end
        return false, 'job_not_allowed'
    end

    local jobs, identifier = getCachedJobs(sourceId)
    if not jobs then return false, 'player_not_found' end

    local existing, existingIndex = findStoredJob(jobs, jobName)
    local maxJobs = math.max(1, tonumber(Config.MaxJobs) or 1)
    if not isDefaultJob and not options.bypassLimit and not existing and #jobs >= maxJobs then
        if options.notify ~= false then notify(sourceId, _L('max_jobs'), 'error') end
        return false, 'max_jobs'
    end

    if not Database.UpsertJob(identifier, canonicalJob) then
        return false, 'database_error'
    end

    local stored = {
        name = canonicalJob.name,
        label = canonicalJob.label,
        grade = canonicalJob.grade,
        gradeLabel = canonicalJob.gradeLabel
    }

    if existingIndex then
        jobs[existingIndex] = stored
    else
        jobs[#jobs + 1] = stored
    end

    if options.notify ~= false and (not existing or options.notifyExisting ~= false) then
        local key = existing and 'job_updated' or 'job_added'
        notify(sourceId, _L(key, { job = canonicalJob.label }), 'success')
    end

    return true, existing and 'updated' or 'added'
end

ensureDefaultJob = function(sourceId)
    if not ensureReady(sourceId) then return false end

    local defaultJobName = normalizeJobName(Config.DefaultJob)
    if not defaultJobName then return false end

    local canonicalJob = Framework.GetJob(defaultJobName, Config.DefaultGrade)
    if not canonicalJob then return false end

    local jobs, identifier = getCachedJobs(sourceId)
    if not jobs then return false end

    local existing, existingIndex = findStoredJob(jobs, defaultJobName)
    if existing then
        if existing.label ~= canonicalJob.label or existing.grade ~= canonicalJob.grade or existing.gradeLabel ~= canonicalJob.gradeLabel then
            if not Database.UpsertJob(identifier, canonicalJob) then return false end
            jobs[existingIndex] = {
                name = canonicalJob.name,
                label = canonicalJob.label,
                grade = canonicalJob.grade,
                gradeLabel = canonicalJob.gradeLabel
            }
        end

        return true
    end

    return addPlayerJob(sourceId, defaultJobName, Config.DefaultGrade, {
        notify = false,
        bypassFilters = true,
        bypassLimit = true,
        skipDefault = true
    })
end

local function isPlayerOffDuty(sourceId)
    local currentJob = Framework.GetCurrentJob(sourceId)
    if not currentJob then return true end

    local offPrefix = Config.OffDutyPrefix or 'off_'
    local currentJobName = currentJob.name
    local isOffPrefix = #offPrefix > 0 and currentJobName:sub(1, #offPrefix) == offPrefix

    if playerDutyState[sourceId] ~= nil then
        return playerDutyState[sourceId] == true
    end

    if currentJob.onduty ~= nil then
        return currentJob.onduty == false
    end

    return isOffPrefix
end

local function captureCurrentJob(sourceId, shouldNotify)
    if not Config.AutoSaveJobs or not resourceReady then return false end

    local currentJob = Framework.GetCurrentJob(sourceId)
    if not currentJob then return false end

    local jobName = currentJob.name
    local offPrefix = Config.OffDutyPrefix or 'off_'
    if #offPrefix > 0 and jobName:sub(1, #offPrefix) == offPrefix then
        jobName = jobName:sub(#offPrefix + 1)
    end

    return addPlayerJob(sourceId, jobName, currentJob.grade, {
        notify = shouldNotify == true,
        notifyExisting = false
    })
end

local function setActiveJob(sourceId, jobName, options)
    options = options or {}
    if not ensureReady(sourceId) then return false, 'not_ready' end

    jobName = normalizeJobName(jobName)
    if not jobName then return false, 'invalid_job' end

    if not ensureDefaultJob(sourceId) then
        if options.notify ~= false then notify(sourceId, _L('default_job_invalid'), 'error') end
        return false, 'default_job_invalid'
    end

    local jobs = getCachedJobs(sourceId)
    local storedJob = findStoredJob(jobs, jobName)
    if not storedJob then
        if options.notify ~= false then notify(sourceId, _L('job_not_owned'), 'error') end
        return false, 'job_not_owned'
    end

    local currentJob = Framework.GetCurrentJob(sourceId)
    if currentJob and currentJob.name == jobName and currentJob.grade == storedJob.grade then
        return true, 'already_active'
    end

    local now = os.time()
    local cooldown = math.max(0, tonumber(Config.SwitchCooldown) or 0)
    local availableAt = switchCooldowns[sourceId] or 0
    if not options.ignoreCooldown and availableAt > now then
        local remaining = availableAt - now
        if options.notify ~= false then
            notify(sourceId, _L('cooldown', { seconds = remaining }), 'error')
        end
        return false, 'cooldown'
    end

    local canonicalJob, validationError = Framework.GetJob(jobName, storedJob.grade)
    if not canonicalJob then
        if options.notify ~= false then notify(sourceId, _L(validationError), 'error') end
        return false, validationError
    end

    if not isJobAllowed(jobName) then
        if options.notify ~= false then notify(sourceId, _L('job_not_allowed'), 'error') end
        return false, 'job_not_allowed'
    end

    if not Framework.SetJob(sourceId, jobName, canonicalJob.grade) then
        return false, 'set_job_failed'
    end

    playerDutyState[sourceId] = nil

    switchCooldowns[sourceId] = now + cooldown
    Database.UpsertJob(Framework.GetIdentifier(sourceId), canonicalJob)

    storedJob.label = canonicalJob.label
    storedJob.grade = canonicalJob.grade
    storedJob.gradeLabel = canonicalJob.gradeLabel

    if options.notify ~= false then
        notify(sourceId, _L('job_changed', { job = canonicalJob.label }), 'success')
    end

    if type(SendDiscordLog) == 'function' then
        local playerName = GetPlayerName(sourceId) or 'Neznámý'
        local identifier = Framework.GetIdentifier(sourceId) or 'N/A'
        SendDiscordLog('JobChange', 'Změna Aktivní Práce',
            ('Hráč **%s** (`ID: %s`) si změnil aktivní práci.'):format(playerName, sourceId),
            {
                { name = 'Hráč', value = playerName .. ' (' .. identifier .. ')', inline = true },
                { name = 'Nová práce', value = canonicalJob.label .. ' (' .. canonicalJob.name .. ')', inline = true },
                { name = 'Hodnost', value = canonicalJob.gradeLabel .. ' (' .. canonicalJob.grade .. ')', inline = true }
            }
        )
    end

    return true, 'changed'
end

local function removePlayerJob(sourceId, jobName, options)
    options = options or {}
    if not ensureReady(sourceId) then return false, 'not_ready' end

    jobName = normalizeJobName(jobName)
    if not jobName then return false, 'invalid_job' end

    if not ensureDefaultJob(sourceId) then
        if options.notify ~= false then notify(sourceId, _L('default_job_invalid'), 'error') end
        return false, 'default_job_invalid'
    end

    if not options.admin and not Config.AllowPlayerRemove then
        notify(sourceId, _L('remove_disabled'), 'error')
        return false, 'remove_disabled'
    end

    local defaultJobName = normalizeJobName(Config.DefaultJob)
    if jobName == defaultJobName then
        if options.notify ~= false then notify(sourceId, _L('cannot_remove_default'), 'error') end
        return false, 'cannot_remove_default'
    end

    local jobs, identifier = getCachedJobs(sourceId)
    local storedJob, storedIndex = findStoredJob(jobs, jobName)
    if not storedJob then
        if options.notify ~= false then notify(sourceId, _L('job_not_owned'), 'error') end
        return false, 'job_not_owned'
    end

    local currentJob = Framework.GetCurrentJob(sourceId)
    local isActive = currentJob and currentJob.name == jobName
    local defaultJob

    if isActive then
        defaultJob = Framework.GetJob(defaultJobName, Config.DefaultGrade)
        if not defaultJob then
            if options.notify ~= false then notify(sourceId, _L('default_job_invalid'), 'error') end
            return false, 'default_job_invalid'
        end
    end

    if not Database.DeleteJob(identifier, jobName) then
        return false, 'database_error'
    end

    table.remove(jobs, storedIndex)

    if isActive then
        if not Framework.SetJob(sourceId, defaultJob.name, defaultJob.grade) then
            Database.UpsertJob(identifier, storedJob)
            table.insert(jobs, storedIndex, storedJob)
            return false, 'set_job_failed'
        end

        addPlayerJob(sourceId, defaultJob.name, defaultJob.grade, {
            notify = false,
            bypassFilters = true
        })
    end

    if options.notify ~= false then
        local messageKey = isActive and 'active_removed_default' or 'job_removed'
        notify(sourceId, _L(messageKey, { job = storedJob.label }), 'success')
    end

    if type(SendDiscordLog) == 'function' then
        local playerName = GetPlayerName(sourceId) or 'Neznámý'
        local ident = identifier or Framework.GetIdentifier(sourceId) or 'N/A'
        SendDiscordLog('JobRemove', 'Odebrání Práce',
            ('Hráč **%s** (`ID: %s`) si odebral práci **%s**.'):format(playerName, sourceId, storedJob.label),
            {
                { name = 'Hráč', value = playerName .. ' (' .. ident .. ')', inline = true },
                { name = 'Odebraná práce', value = storedJob.label .. ' (' .. storedJob.name .. ')', inline = true }
            }
        )
    end

    return true, 'removed'
end

local function serializeJobs(sourceId)
    ensureDefaultJob(sourceId)
    local jobs = getCachedJobs(sourceId) or {}
    local currentlyOff = isPlayerOffDuty(sourceId)
    local currentJob = Framework.GetCurrentJob(sourceId)
    local currentJobName = currentJob and currentJob.name or ''
    local offPrefix = Config.OffDutyPrefix or 'off_'
    local baseCurrentName = (#offPrefix > 0 and currentJobName:sub(1, #offPrefix) == offPrefix) and currentJobName:sub(#offPrefix + 1) or currentJobName

    local payload = {}
    for _, job in ipairs(jobs) do
        local canonical = Framework.GetJob(job.name, job.grade)
        local baseJobName = (#offPrefix > 0 and job.name:sub(1, #offPrefix) == offPrefix) and job.name:sub(#offPrefix + 1) or job.name
        local isActive = (currentJobName == job.name or baseCurrentName == baseJobName or currentJobName == baseJobName)

        payload[#payload + 1] = {
            name = job.name,
            label = job.label,
            grade = job.grade,
            gradeLabel = job.gradeLabel,
            salary = canonical and canonical.salary or 0,
            active = isActive,
            onDuty = isActive and not currentlyOff
        }
    end

    return payload
end

local function sendMenu(sourceId, openMenu)
    if not ensureReady(sourceId) then return end

    if Config.AutoSaveJobs then
        captureCurrentJob(sourceId, false)
    end

    TriggerClientEvent(openMenu and 'rs_multijob:client:open' or 'rs_multijob:client:update', sourceId, {
        jobs = serializeJobs(sourceId),
        maxJobs = math.max(1, tonumber(Config.MaxJobs) or 1),
        allowRemove = Config.AllowPlayerRemove == true,
        defaultJob = normalizeJobName(Config.DefaultJob) or '',
        showSalary = Config.ShowSalary == true,
        salaryFormat = Config.SalaryFormat or '$%s',
        enableDuty = Config.EnableDuty == true,
        offDutyPrefix = Config.OffDutyPrefix or 'off_',
        jobIcons = Config.JobIcons or {},
        locale = GetLocaleData()
    })
end

local function runLocked(sourceId, callback)
    sourceId = tonumber(sourceId)
    if not sourceId or sourceId <= 0 then return false end

    if actionLocks[sourceId] then
        notify(sourceId, _L('action_busy'), 'error')
        return
    end

    actionLocks[sourceId] = true
    CreateThread(function()
        local ok, err = pcall(callback)
        actionLocks[sourceId] = nil

        if not ok then
            print(('[rs_multijob] Player action failed for %s: %s'):format(sourceId, err))
        end
    end)
end

local function callLocked(sourceId, callback)
    sourceId = tonumber(sourceId)
    if not sourceId or sourceId <= 0 then return false, 'player_not_found' end

    while actionLocks[sourceId] do
        Wait(0)
    end

    actionLocks[sourceId] = true
    local results = table.pack(pcall(callback))
    actionLocks[sourceId] = nil

    if not results[1] then
        print(('[rs_multijob] Locked operation failed for %s: %s'):format(sourceId, results[2]))
        return false, 'internal_error'
    end

    return table.unpack(results, 2, results.n)
end

RegisterCommand(Config.Command, function(sourceId)
    sourceId = tonumber(sourceId) or 0
    if sourceId == 0 then
        print(('[rs_multijob] /%s can only be used by a player.'):format(Config.Command))
        return
    end

    runLocked(sourceId, function()
        sendMenu(sourceId, true)
    end)
end, false)

RegisterNetEvent('rs_multijob:server:activate', function(jobName)
    local sourceId = tonumber(source)
    if not sourceId then return end
    runLocked(sourceId, function()
        setActiveJob(sourceId, jobName)
        sendMenu(sourceId, false)
    end)
end)

local function togglePlayerDuty(sourceId)
    if not Config.EnableDuty then return false, 'duty_disabled' end
    local player = Framework.GetPlayer(sourceId)
    if not player then return false, 'player_not_found' end

    local currentJob = Framework.GetCurrentJob(sourceId)
    if not currentJob then return false, 'invalid_job' end

    local currentlyOff = isPlayerOffDuty(sourceId)
    local nextIsOffDuty = not currentlyOff

    if (Framework.name == 'qbcore' or Framework.name == 'qbox') then
        local dutySet = false
        if Framework.name == 'qbox' then
            local ok = pcall(function()
                exports['qbx_core']:SetJobDuty(sourceId, not nextIsOffDuty)
            end)
            if ok then dutySet = true end
        end

        if not dutySet and player.Functions and player.Functions.SetJobDuty then
            player.Functions.SetJobDuty(not nextIsOffDuty)
            dutySet = true
        end

        if dutySet then
            playerDutyState[sourceId] = nextIsOffDuty
            local stateLabel = nextIsOffDuty and _L('duty_off') or _L('duty_on')
            notify(sourceId, _L('duty_changed', { state = stateLabel }), 'info')
            return true, stateLabel
        end
    end

    local offPrefix = Config.OffDutyPrefix or 'off_'
    local currentJobName = currentJob.name

    if #offPrefix > 0 then
        local targetJobName
        if currentlyOff and currentJobName:sub(1, #offPrefix) == offPrefix then
            targetJobName = currentJobName:sub(#offPrefix + 1)
        elseif not currentlyOff and currentJobName:sub(1, #offPrefix) ~= offPrefix then
            targetJobName = offPrefix .. currentJobName
        end

        if targetJobName then
            local canonicalTarget = Framework.GetJob(targetJobName, currentJob.grade)
            if canonicalTarget and Framework.SetJob(sourceId, targetJobName, currentJob.grade) then
                playerDutyState[sourceId] = nextIsOffDuty
                local stateLabel = nextIsOffDuty and _L('duty_off') or _L('duty_on')
                notify(sourceId, _L('duty_changed', { state = stateLabel }), 'info')
                return true, stateLabel
            end
        end
    end

    playerDutyState[sourceId] = nextIsOffDuty
    local stateLabel = nextIsOffDuty and _L('duty_off') or _L('duty_on')
    notify(sourceId, _L('duty_changed', { state = stateLabel }), 'info')
    return true, stateLabel
end

RegisterNetEvent('rs_multijob:server:remove', function(jobName)
    local sourceId = tonumber(source)
    if not sourceId then return end
    runLocked(sourceId, function()
        removePlayerJob(sourceId, jobName)
        sendMenu(sourceId, false)
    end)
end)

RegisterNetEvent('rs_multijob:server:toggleDuty', function()
    local sourceId = tonumber(source)
    if not sourceId then return end
    runLocked(sourceId, function()
        togglePlayerDuty(sourceId)
        sendMenu(sourceId, false)
    end)
end)

local function scheduleJobCapture(sourceId)
    sourceId = tonumber(sourceId)
    if not sourceId or sourceId <= 0 then return end

    SetTimeout(250, function()
        if GetPlayerName(sourceId) and resourceReady then
            callLocked(sourceId, function()
                ensureDefaultJob(sourceId)
                captureCurrentJob(sourceId, true)
            end)
        end
    end)
end

AddEventHandler('esx:setJob', function(playerId)
    local eventSource = tonumber(source)
    scheduleJobCapture(eventSource and eventSource > 0 and eventSource or tonumber(playerId))
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(playerId)
    local eventSource = tonumber(source)
    scheduleJobCapture(eventSource and eventSource > 0 and eventSource or tonumber(playerId))
end)

AddEventHandler('qbx_core:server:onJobUpdate', function(sourceId, job)
    scheduleJobCapture(tonumber(sourceId) or tonumber(source))
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    scheduleJobCapture(tonumber(playerId) or tonumber(source))
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local sourceId = tonumber(source)
    if (not sourceId or sourceId <= 0) and player and player.PlayerData then
        sourceId = tonumber(player.PlayerData.source)
    end
    scheduleJobCapture(sourceId)
end)

AddEventHandler('qbx_core:server:playerLoaded', function(sourceId)
    scheduleJobCapture(tonumber(sourceId) or tonumber(source))
end)

AddEventHandler('playerDropped', function()
    local sourceId = tonumber(source) or source
    playerCache[sourceId] = nil
    switchCooldowns[sourceId] = nil
    actionLocks[sourceId] = nil
    playerDutyState[sourceId] = nil
end)

local function registerAdminCommands()
    RegisterCommand(Config.Admin.Commands.Add, function(adminSource, args)
        adminSource = tonumber(adminSource) or 0
        CreateThread(function()
            if not Framework.HasAdminPermission(adminSource) then
                notify(adminSource, _L('no_permission'), 'error')
                return
            end

            local target = tonumber(args[1])
            local grade = tonumber(args[3])
            if not target or not args[2] or not grade then
                sendChat(adminSource, _L('admin_add_usage', { command = Config.Admin.Commands.Add }))
                return
            end

            if not Framework.GetPlayer(target) then
                notify(adminSource, _L('player_not_found'), 'error')
                return
            end

            local success, reason = callLocked(target, function()
                return addPlayerJob(target, args[2], grade, { notify = true })
            end)
            if success and adminSource ~= target then
                notify(adminSource, _L(reason == 'updated' and 'job_updated' or 'job_added', { job = args[2] }), 'success')
            elseif not success and adminSource ~= target then
                notify(adminSource, _L(reason), 'error')
            end
        end)
    end, false)

    RegisterCommand(Config.Admin.Commands.Remove, function(adminSource, args)
        adminSource = tonumber(adminSource) or 0
        CreateThread(function()
            if not Framework.HasAdminPermission(adminSource) then
                notify(adminSource, _L('no_permission'), 'error')
                return
            end

            local target = tonumber(args[1])
            if not target or not args[2] then
                sendChat(adminSource, _L('admin_remove_usage', { command = Config.Admin.Commands.Remove }))
                return
            end

            if not Framework.GetPlayer(target) then
                notify(adminSource, _L('player_not_found'), 'error')
                return
            end

            local success, reason = callLocked(target, function()
                return removePlayerJob(target, args[2], { admin = true, notify = true })
            end)
            if success and adminSource ~= target then
                notify(adminSource, _L('job_removed', { job = args[2] }), 'success')
            elseif not success and adminSource ~= target then
                notify(adminSource, _L(reason), 'error')
            end
        end)
    end, false)

    RegisterCommand(Config.Admin.Commands.List, function(adminSource, args)
        adminSource = tonumber(adminSource) or 0
        CreateThread(function()
            if not Framework.HasAdminPermission(adminSource) then
                notify(adminSource, _L('no_permission'), 'error')
                return
            end

            local target = tonumber(args[1])
            if not target then
                sendChat(adminSource, _L('admin_list_usage', { command = Config.Admin.Commands.List }))
                return
            end

            if not Framework.GetPlayer(target) then
                notify(adminSource, _L('player_not_found'), 'error')
                return
            end

            local jobs = serializeJobs(target)
            sendChat(adminSource, _L('jobs_heading', { id = target }))
            if #jobs == 0 then
                sendChat(adminSource, _L('jobs_empty'))
                return
            end

            for _, job in ipairs(jobs) do
                sendChat(adminSource, _L('job_list_item', {
                    job = ('%s [%s]'):format(job.label, job.name),
                    grade = ('%s - %s'):format(job.grade, job.gradeLabel),
                    active = job.active and _L('active_suffix') or ''
                }))
            end
        end)
    end, false)
end

CreateThread(function()
    while not Framework.Initialize() do
        Wait(1000)
    end

    while not Database.Initialize() do
        Wait(1000)
    end

    resourceReady = true
    if Config.Admin.Enabled ~= false then
        registerAdminCommands()
    end

    for _, playerId in ipairs(GetPlayers()) do
        scheduleJobCapture(tonumber(playerId))
    end

    while true do
        Wait(math.max(5, tonumber(Config.AutoSaveInterval) or 30) * 1000)
        if Config.AutoSaveJobs then
            for _, playerId in ipairs(GetPlayers()) do
                local sourceId = tonumber(playerId)
                CreateThread(function()
                    callLocked(sourceId, function()
                        captureCurrentJob(sourceId, false)
                    end)
                end)
            end
        end
    end
end)

exports('GetPlayerJobs', function(sourceId)
    sourceId = tonumber(sourceId)
    if not resourceReady or not sourceId or not Framework.GetPlayer(sourceId) then return {} end
    return serializeJobs(sourceId)
end)

exports('AddPlayerJob', function(sourceId, jobName, grade)
    sourceId = tonumber(sourceId)
    return callLocked(sourceId, function()
        return addPlayerJob(sourceId, jobName, grade, { notify = true })
    end)
end)

exports('RemovePlayerJob', function(sourceId, jobName)
    sourceId = tonumber(sourceId)
    return callLocked(sourceId, function()
        return removePlayerJob(sourceId, jobName, { admin = true, notify = true })
    end)
end)

exports('HasPlayerJob', function(sourceId, jobName)
    sourceId = tonumber(sourceId)
    jobName = normalizeJobName(jobName)
    if not resourceReady or not sourceId or not jobName or not Framework.GetPlayer(sourceId) then return false end

    ensureDefaultJob(sourceId)
    local jobs = getCachedJobs(sourceId)
    return findStoredJob(jobs, jobName) ~= nil
end)

exports('SetActiveJob', function(sourceId, jobName)
    sourceId = tonumber(sourceId)
    return callLocked(sourceId, function()
        return setActiveJob(sourceId, jobName, { notify = true })
    end)
end)

exports('ToggleDuty', function(sourceId)
    sourceId = tonumber(sourceId)
    return callLocked(sourceId, function()
        return togglePlayerDuty(sourceId)
    end)
end)

exports('IsOnDuty', function(sourceId)
    sourceId = tonumber(sourceId)
    if not sourceId then return false end
    return not isPlayerOffDuty(sourceId)
end)
