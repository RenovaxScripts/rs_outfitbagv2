Database = {
    ready = false
}

local adapter
local tableName

local function safeResolve(promiseObject, value)
    if promiseObject then
        promiseObject:resolve(value)
    end
end

local function query(sql, parameters)
    local resultPromise = promise.new()
    local resolved = false

    local function done(result)
        if resolved then return end
        resolved = true
        safeResolve(resultPromise, result or {})
    end

    local ok, err = pcall(function()
        if adapter == 'oxmysql' then
            exports.oxmysql:query(sql, parameters or {}, done)
        else
            exports['mysql-async']:mysql_fetch_all(sql, parameters or {}, done)
        end
    end)

    if not ok then
        print(('[rs_multijob] Database query failed: %s'):format(err))
        done({})
    end

    return Citizen.Await(resultPromise)
end

local function execute(sql, parameters)
    local resultPromise = promise.new()
    local resolved = false

    local function done(result)
        if resolved then return end
        resolved = true
        if result == nil then result = false end
        safeResolve(resultPromise, result)
    end

    local ok, err = pcall(function()
        if adapter == 'oxmysql' then
            exports.oxmysql:update(sql, parameters or {}, done)
        else
            exports['mysql-async']:mysql_execute(sql, parameters or {}, done)
        end
    end)

    if not ok then
        print(('[rs_multijob] Database execution failed: %s'):format(err))
        done(false)
    end

    return Citizen.Await(resultPromise)
end

local function createTable()
    local sql = ([=[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(128) NOT NULL,
            `job_name` VARCHAR(64) NOT NULL,
            `job_label` VARCHAR(128) NOT NULL,
            `grade` INT NOT NULL DEFAULT 0,
            `grade_label` VARCHAR(128) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_identifier_job` (`identifier`, `job_name`),
            KEY `idx_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]=]):format(tableName)

    return execute(sql, {}) ~= false
end

function Database.Initialize()
    adapter = string.lower(tostring(Config.Database or 'oxmysql'))
    if adapter ~= 'oxmysql' and adapter ~= 'mysql-async' then
        print(('[rs_multijob] Unsupported database adapter: %s'):format(adapter))
        return false
    end

    tableName = tostring(Config.DatabaseTable or 'rs_multijob_jobs')
    if not tableName:match('^[%w_]+$') then
        print('[rs_multijob] Config.DatabaseTable contains invalid characters.')
        return false
    end

    local resourceName = adapter == 'oxmysql' and 'oxmysql' or 'mysql-async'
    if GetResourceState(resourceName) ~= 'started' then
        return false
    end

    if Config.AutoCreateTable then
        if not createTable() then return false end
    end

    Database.ready = true
    print(('[rs_multijob] Database adapter ready: %s'):format(adapter))
    return true
end

function Database.GetJobs(identifier)
    if not Database.ready then return {} end

    return query(('SELECT `job_name`, `job_label`, `grade`, `grade_label`, `created_at` FROM `%s` WHERE `identifier` = @identifier ORDER BY `created_at` ASC, `id` ASC'):format(tableName), {
        ['@identifier'] = identifier
    })
end

function Database.UpsertJob(identifier, job)
    if not Database.ready then return false end

    local affected = execute(([=[
        INSERT INTO `%s` (`identifier`, `job_name`, `job_label`, `grade`, `grade_label`)
        VALUES (@identifier, @job_name, @job_label, @grade, @grade_label)
        ON DUPLICATE KEY UPDATE
            `job_label` = VALUES(`job_label`),
            `grade` = VALUES(`grade`),
            `grade_label` = VALUES(`grade_label`)
    ]=]):format(tableName), {
        ['@identifier'] = identifier,
        ['@job_name'] = job.name,
        ['@job_label'] = job.label,
        ['@grade'] = job.grade,
        ['@grade_label'] = job.gradeLabel
    })

    return affected ~= false
end

function Database.DeleteJob(identifier, jobName)
    if not Database.ready then return false end

    local affected = execute(('DELETE FROM `%s` WHERE `identifier` = @identifier AND `job_name` = @job_name'):format(tableName), {
        ['@identifier'] = identifier,
        ['@job_name'] = jobName
    })

    return tonumber(affected or 0) > 0
end
