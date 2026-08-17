Framework = {
    ready = false,
    name = nil,
    object = nil
}

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

local function detectFramework()
    local configured = string.lower(tostring(Config.Framework or 'auto'))
    if configured == 'qbox' or configured == 'qbx' then
        return 'qbox'
    elseif configured == 'esx' or configured == 'qbcore' then
        return configured
    end

    for _, name in ipairs(Config.AutoFrameworkPriority or { 'qbox', 'esx', 'qbcore' }) do
        if (name == 'qbox' or name == 'qbx') and resourceStarted('qbx_core') then
            return 'qbox'
        end

        if name == 'esx' and resourceStarted('es_extended') then
            return 'esx'
        end

        if name == 'qbcore' and resourceStarted('qb-core') then
            return 'qbcore'
        end
    end

    return nil
end

function Framework.Initialize()
    local detected = detectFramework()
    if not detected then return false end

    local ok, object
    if detected == 'qbox' then
        ok, object = pcall(function()
            return exports['qbx_core']
        end)
        if not ok or not object then
            ok, object = pcall(function()
                return exports['qb-core']:GetCoreObject()
            end)
        end
    elseif detected == 'esx' then
        ok, object = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
    else
        ok, object = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
    end

    if not ok or not object then return false end

    Framework.name = detected
    Framework.object = object
    Framework.ready = true
    print(('[rs_multijob] Framework detected: %s'):format(detected))
    return true
end

function Framework.GetPlayer(sourceId)
    if not Framework.ready then return nil end
    sourceId = tonumber(sourceId)
    if not sourceId then return nil end

    if Framework.name == 'esx' then
        return Framework.object.GetPlayerFromId(sourceId)
    elseif Framework.name == 'qbox' then
        local player
        local ok = pcall(function()
            player = exports['qbx_core']:GetPlayer(sourceId)
        end)
        if ok and player then return player end
        if Framework.object and Framework.object.Functions and Framework.object.Functions.GetPlayer then
            return Framework.object.Functions.GetPlayer(sourceId)
        end
        return nil
    end

    return Framework.object.Functions.GetPlayer(sourceId)
end

function Framework.GetIdentifier(sourceId)
    local player = Framework.GetPlayer(sourceId)
    if not player then return nil end

    if Framework.name == 'esx' then
        return player.identifier or (player.getIdentifier and player.getIdentifier())
    end

    local data = player.PlayerData or {}
    return data.citizenid or data.license or GetPlayerIdentifierByType(sourceId, 'license')
end

function Framework.GetCurrentJob(sourceId)
    local player = Framework.GetPlayer(sourceId)
    if not player then return nil end

    local job
    if Framework.name == 'esx' then
        job = player.getJob and player.getJob() or player.job
    else
        job = player.PlayerData and player.PlayerData.job
    end

    if not job or not job.name then return nil end

    local grade = job.grade
    local gradeName
    local gradeLabel
    local salary = 0

    if type(grade) == 'table' then
        gradeName = grade.name
        gradeLabel = grade.name or grade.label
        salary = tonumber(grade.salary or grade.payment) or 0
        grade = grade.level
    else
        gradeName = job.grade_name
        gradeLabel = job.grade_label
        salary = tonumber(job.grade_salary or job.salary or job.payment) or 0
    end

    local onduty = true
    if type(job.onduty) == 'boolean' then
        onduty = job.onduty
    end

    return {
        name = tostring(job.name),
        label = tostring(job.label or job.name),
        grade = tonumber(grade) or 0,
        gradeName = tostring(gradeName or grade or 0),
        gradeLabel = tostring(gradeLabel or gradeName or grade or 0),
        salary = tonumber(salary) or 0,
        onduty = onduty
    }
end

local function findGrade(grades, requestedGrade)
    local numericGrade = tonumber(requestedGrade)
    if not numericGrade or numericGrade < 0 or numericGrade % 1 ~= 0 then return nil end

    local gradeData = grades and (grades[tostring(numericGrade)] or grades[numericGrade])
    if gradeData then return gradeData, numericGrade end

    if grades then
        for key, value in pairs(grades) do
            local level = tonumber(value.grade or value.level or key)
            if level == numericGrade then
                return value, numericGrade
            end
        end
    end

    return nil
end

function Framework.GetJob(jobName, requestedGrade)
    if not Framework.ready or type(jobName) ~= 'string' then return nil, 'invalid_job' end

    local job
    if Framework.name == 'esx' then
        local jobs = Framework.object.GetJobs and Framework.object.GetJobs() or Framework.object.Jobs
        job = jobs and jobs[jobName]
    elseif Framework.name == 'qbox' then
        local ok, jobs = pcall(function()
            return exports['qbx_core']:GetJobs()
        end)
        if ok and jobs and jobs[jobName] then
            job = jobs[jobName]
        elseif Framework.object and Framework.object.Shared and Framework.object.Shared.Jobs then
            job = Framework.object.Shared.Jobs[jobName]
        end
    else
        job = Framework.object.Shared and Framework.object.Shared.Jobs and Framework.object.Shared.Jobs[jobName]
    end

    if not job then return nil, 'invalid_job' end

    local gradeData, numericGrade = findGrade(job.grades, requestedGrade)
    if not gradeData then return nil, 'invalid_grade' end

    return {
        name = jobName,
        label = tostring(job.label or jobName),
        grade = numericGrade,
        gradeName = tostring(gradeData.name or numericGrade),
        gradeLabel = tostring(gradeData.label or gradeData.name or numericGrade),
        salary = tonumber(gradeData.salary or gradeData.payment or 0) or 0
    }
end

function Framework.SetJob(sourceId, jobName, grade)
    local player = Framework.GetPlayer(sourceId)
    if not player then return false end

    if Framework.name == 'esx' then
        player.setJob(jobName, grade)
    elseif Framework.name == 'qbox' then
        local ok, result = pcall(function()
            return exports['qbx_core']:SetJob(sourceId, jobName, grade)
        end)
        if not ok or result == false then
            if player.Functions and player.Functions.SetJob then
                local res = player.Functions.SetJob(jobName, grade)
                if res == false then return false end
            else
                return false
            end
        end
    else
        local result = player.Functions.SetJob(jobName, grade)
        if result == false then return false end
    end

    return true
end

function Framework.HasAdminPermission(sourceId)
    sourceId = tonumber(sourceId) or 0
    if sourceId == 0 then return true end

    local permission = Config.Admin.Permission
    if permission.UseAce and IsPlayerAceAllowed(sourceId, permission.Ace) then
        return true
    end

    local player = Framework.GetPlayer(sourceId)
    if not player then return false end

    if Framework.name == 'esx' and permission.UseESXGroups then
        local group = player.getGroup and player.getGroup() or player.group
        if group and permission.ESXGroups[group] then return true end
    end

    if (Framework.name == 'qbox' or Framework.name == 'qbcore') and (permission.UseQboxGroups or permission.UseQBCorePermissions) then
        local qboxGroups = permission.QboxGroups or permission.QBCorePermissions or {}
        for _, groupName in ipairs(qboxGroups) do
            local ok, hasGroup = pcall(function()
                return exports['qbx_core']:HasGroup(sourceId, groupName)
            end)
            if ok and hasGroup then return true end
        end
    end

    if Framework.name == 'qbcore' and permission.UseQBCorePermissions then
        for _, qbPermission in ipairs(permission.QBCorePermissions or {}) do
            if Framework.object and Framework.object.Functions and Framework.object.Functions.HasPermission then
                if Framework.object.Functions.HasPermission(sourceId, qbPermission) then
                    return true
                end
            end
        end
    end

    return false
end
