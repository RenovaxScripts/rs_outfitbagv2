local RESOURCE = GetCurrentResourceName()
local ESX, QBCore
local detectors = {}
local detectorCooldowns = {}
local manualCooldowns = {}
local temporaryId = -1

local function T(key, ...)
    local dictionary = Locales[Config.Locale] or Locales.en or {}
    local value = dictionary[key] or key
    if select('#', ...) > 0 then
        return value:format(...)
    end
    return value
end

local function debugPrint(message, ...)
    if Config.Debug then
        print(('[%s] %s'):format(RESOURCE, message:format(...)))
    end
end

local function initialiseFramework()
    if Config.Framework == 'esx' then
        ESX = exports.es_extended:getSharedObject()
    elseif Config.Framework == 'qb' then
        QBCore = exports['qb-core']:GetCoreObject()
    else
        error(('[%s] Unsupported framework: %s'):format(RESOURCE, tostring(Config.Framework)))
    end
end

local function getPlayer(source)
    if Config.Framework == 'esx' then
        return ESX and ESX.GetPlayerFromId(source)
    end
    return QBCore and QBCore.Functions.GetPlayer(source)
end

local function getJob(source)
    local player = getPlayer(source)
    if not player then return nil end

    if Config.Framework == 'esx' then
        return player.job and player.job.name or nil
    end

    return player.PlayerData.job and player.PlayerData.job.name or nil
end

local function getPlayerNameSafe(source)
    local player = getPlayer(source)
    if Config.Framework == 'esx' and player and player.getName then
        return player.getName()
    elseif player and player.PlayerData then
        local charinfo = player.PlayerData.charinfo or {}
        local fullName = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
        if fullName ~= '' then return fullName end
    end
    return GetPlayerName(source) or ('ID %s'):format(source)
end

local function getIdentifier(source)
    local player = getPlayer(source)
    if Config.Framework == 'esx' and player then
        return player.identifier
    elseif player and player.PlayerData then
        return player.PlayerData.citizenid or player.PlayerData.license
    end
    return GetPlayerIdentifierByType(source, 'license')
end

local function isAdmin(source)
    if source == 0 then return true end
    if IsPlayerAceAllowed(source, 'metalscanner.admin') then return true end

    local player = getPlayer(source)
    if not player then return false end

    local adminGroups = (ServerConfig and ServerConfig.AdminGroups) or Config.AdminGroups or {}

    if Config.Framework == 'esx' then
        local group = player.getGroup and player.getGroup() or player.group
        return group and adminGroups[group] == true
    end

    for group in pairs(adminGroups) do
        if QBCore.Functions.HasPermission(source, group) then return true end
    end
    return false
end

local function decodeList(value)
    if type(value) == 'table' then return value end
    if not value or value == '' then return {} end

    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or {}
end

local function cleanList(value)
    local result, seen = {}, {}
    for _, entry in ipairs(decodeList(value)) do
        if type(entry) == 'string' then
            entry = entry:lower():gsub('^%s*(.-)%s*$', '%1')
            if entry ~= '' and not seen[entry] then
                seen[entry] = true
                result[#result + 1] = entry
            end
        end
    end
    return result
end

local function listContains(list, value)
    if not value then return false end
    value = value:lower()
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end

local function bool(value)
    return value == true or value == 1 or value == '1'
end

local function serialiseDetector(detector)
    return {
        id = detector.id,
        name = detector.name,
        type = detector.type,
        coords = { x = detector.coords.x, y = detector.coords.y, z = detector.coords.z },
        heading = detector.heading,
        radius = detector.radius,
        cooldown = detector.cooldown,
        spawn_model = detector.spawn_model,
        active = detector.active,
        job_restriction = detector.job_restriction,
        notify_jobs = detector.notify_jobs,
        ignored_jobs = detector.ignored_jobs,
        trigger_dispatch = detector.trigger_dispatch ~= false,
        persistent = detector.persistent
    }
end

local function detectorList()
    local result = {}
    for _, detector in pairs(detectors) do
        result[#result + 1] = serialiseDetector(detector)
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

local function syncDetectors(target)
    TriggerClientEvent('rs_metal_scanner:client:syncDetectors', target or -1, detectorList())
end

local function rowToDetector(row)
    local coords = type(row.coords) == 'table' and row.coords or json.decode(row.coords or '{}')
    return {
        id = tonumber(row.id),
        name = tostring(row.name),
        type = row.type == 'model' and 'model' or 'zone',
        coords = vector3(tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0),
        heading = tonumber(row.heading) or 0.0,
        radius = tonumber(row.radius) or Config.DefaultRadius,
        cooldown = tonumber(row.cooldown) or Config.DefaultCooldown,
        spawn_model = bool(row.spawn_model),
        active = bool(row.active),
        job_restriction = cleanList(row.job_restriction),
        notify_jobs = cleanList(row.notify_jobs),
        ignored_jobs = cleanList(row.ignored_jobs),
        trigger_dispatch = row.trigger_dispatch == nil or bool(row.trigger_dispatch),
        persistent = true
    }
end

local function loadDetectors()
    local rows = MySQL.query.await('SELECT * FROM `metal_scanners`') or {}
    detectors = {}
    detectorCooldowns = {}
    for i = 1, #rows do
        local ok, detector = pcall(rowToDetector, rows[i])
        if ok and detector.id then
            detectors[detector.id] = detector
        else
            print(('[%s] Invalid detector row id %s was skipped.'):format(RESOURCE, tostring(rows[i].id)))
        end
    end
    debugPrint('Loaded %d detectors.', #rows)
end

local function validateDetector(input, editingId)
    if type(input) ~= 'table' then return nil, 'invalid_input' end

    local name = type(input.name) == 'string' and input.name:gsub('^%s*(.-)%s*$', '%1') or ''
    local kind = input.type == 'model' and 'model' or input.type == 'zone' and 'zone' or nil
    local coords = input.coords
    local x = coords and tonumber(coords.x)
    local y = coords and tonumber(coords.y)
    local z = coords and tonumber(coords.z)
    local radius = tonumber(input.radius)
    local cooldown = math.floor(tonumber(input.cooldown) or 0)
    local heading = tonumber(input.heading) or 0.0

    if name == '' or #name > 100 or not kind or not x or not y or not z then
        return nil, 'invalid_input'
    end
    if not radius or radius <= 0.0 or radius > Config.MaximumRadius then
        return nil, 'invalid_input'
    end
    if cooldown < Config.MinimumCooldown then
        return nil, 'invalid_input'
    end

    local position = vector3(x, y, z)
    local loweredName = name:lower()
    for id, existing in pairs(detectors) do
        if id ~= editingId and (existing.name:lower() == loweredName or #(existing.coords - position) < Config.DuplicateDistance) then
            return nil, 'duplicate_detector'
        end
    end

    return {
        name = name,
        type = kind,
        coords = position,
        heading = heading % 360.0,
        radius = radius,
        cooldown = cooldown,
        spawn_model = kind == 'model' and input.spawn_model ~= false or false,
        active = input.active ~= false,
        job_restriction = cleanList(input.job_restriction),
        notify_jobs = cleanList(input.notify_jobs),
        ignored_jobs = cleanList(input.ignored_jobs),
        trigger_dispatch = input.trigger_dispatch ~= false,
        persistent = input.persistent ~= false
    }
end

local function isItemMetal(itemName)
    if not itemName then return false end
    local isWeapon = itemName:sub(1, 7) == 'weapon_'
    local isIgnoredWeapon = isWeapon and Config.IgnoredWeapons and Config.IgnoredWeapons[itemName]
    if isWeapon and not isIgnoredWeapon and Config.DetectAllWeapons then
        return true
    elseif Config.MetalItems[itemName] and not Config.WhitelistedItems[itemName] then
        return true
    end
    return false
end

local function scanInventory(target)
    local foundMap = {}

    local okItems, items = pcall(function()
        if GetResourceState('nord_inventory') == 'started' or Config.Inventory == 'nord_inventory' or Config.Inventory == 'nord' then
            return exports.nord_inventory:GetInventoryItems(target)
        end
        return exports[Config.Inventory]:GetInventoryItems(target)
    end)

    local function processItem(item)
        if not item or not item.name then return end
        local itemName = item.name

        if item.metadata and item.metadata.container then
            local okSub, subItems = pcall(function()
                if GetResourceState('nord_inventory') == 'started' or Config.Inventory == 'nord_inventory' or Config.Inventory == 'nord' then
                    local containerInv = exports.nord_inventory:GetContainerInventory(target, item.slot)
                    return containerInv and (containerInv.items or containerInv)
                end
                return exports[Config.Inventory]:GetContainerItems(item.metadata.container)
            end)
            if okSub and subItems then
                for _, subItem in pairs(subItems) do
                    processItem(subItem)
                end
            end
        end

        if isItemMetal(itemName) then
            local count = item.count or 1
            if foundMap[itemName] then
                foundMap[itemName].count = foundMap[itemName].count + count
            else
                foundMap[itemName] = { name = itemName, count = count }
            end
        end
    end

    if okItems and items then
        for _, item in pairs(items) do
            processItem(item)
        end
    else
        for itemName, enabled in pairs(Config.MetalItems) do
            if enabled and not Config.WhitelistedItems[itemName] then
                local ok, count = pcall(function()
                    if GetResourceState('nord_inventory') == 'started' or Config.Inventory == 'nord_inventory' or Config.Inventory == 'nord' then
                        return exports.nord_inventory:GetItemCount(target, itemName) or exports.nord_inventory:Search(target, 'count', itemName)
                    end
                    return exports[Config.Inventory]:Search(target, 'count', itemName)
                end)
                if ok and (tonumber(count) or 0) > 0 then
                    foundMap[itemName] = { name = itemName, count = count }
                end
            end
        end
    end

    local found = {}
    for _, item in pairs(foundMap) do
        found[#found + 1] = item
    end
    table.sort(found, function(a, b) return a.name < b.name end)
    return found
end

local function hasItem(source, itemName)
    local ok, count = pcall(function()
        if GetResourceState('nord_inventory') == 'started' or Config.Inventory == 'nord_inventory' or Config.Inventory == 'nord' then
            return exports.nord_inventory:GetItemCount(source, itemName) or exports.nord_inventory:Search(source, 'count', itemName)
        end
        return exports[Config.Inventory]:Search(source, 'count', itemName)
    end)
    return ok and (tonumber(count) or 0) > 0
end

local function playerDistance(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if pedA <= 0 or pedB <= 0 then return math.huge end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB))
end

local function isInsideDetectorBox(position, detector, tolerance)
    local difference = position - detector.coords
    local angle = math.rad(-(detector.heading or 0.0))
    local cosine, sine = math.cos(angle), math.sin(angle)
    local localX = difference.x * cosine - difference.y * sine
    local localY = difference.x * sine + difference.y * cosine
    local extra = tolerance or 0.0

    return math.abs(localX) <= detector.radius + extra
        and math.abs(localY) <= (Config.BoxZoneDepth * 0.5) + extra
        and math.abs(difference.z) <= (Config.BoxZoneHeight * 0.5) + extra
end

local function sendWebhook(detector, source, found)
    local webhook = (ServerConfig and ServerConfig.DiscordWebhook) or Config.DiscordWebhook or ''
    if not webhook or webhook == '' then return end

    local webhookName = (ServerConfig and ServerConfig.DiscordWebhookName) or Config.DiscordWebhookName or 'RS Metal Scanner'
    local embedColor = (ServerConfig and ServerConfig.DiscordEmbedColor) or 15105570

    local itemText = {}
    for i = 1, #found do
        itemText[#itemText + 1] = ('%s x%s'):format(found[i].name, found[i].count)
    end
    local payload = {
        username = webhookName,
        embeds = {{
            title = 'Metal detected',
            color = embedColor,
            fields = {
                { name = 'Detector', value = ('%s (#%s)'):format(detector.name, detector.id), inline = true },
                { name = 'Player', value = ('%s (%s)'):format(getPlayerNameSafe(source), source), inline = true },
                { name = 'Identifier', value = getIdentifier(source) or 'unknown', inline = false },
                { name = 'Items', value = table.concat(itemText, ', '), inline = false }
            },
            footer = { text = os.date('!%Y-%m-%d %H:%M:%S UTC') }
        }}
    }
    PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function sendDispatch(detector, source, found)
    if SendServerDispatch then
        SendServerDispatch(detector, source, found)
    end
    TriggerClientEvent('rs_metal_scanner:client:triggerDispatch', source, serialiseDetector(detector), found)
end

local function alarmModeIncludes(kind)
    return Config.AlarmMode == kind or Config.AlarmMode == 'beep_and_notify'
end

local function notifyDetection(detector, source, found)
    local playerName = getPlayerNameSafe(source)
    local recipients = {}
    local audience = Config.NotificationAudience
    local notifyJobs = detector.notify_jobs

    if #notifyJobs == 0 then
        for job, enabled in pairs(Config.NotifyJobs) do
            if enabled then notifyJobs[#notifyJobs + 1] = job:lower() end
        end
    end

    if audience.triggeringPlayer then recipients[source] = true end

    for _, playerIdValue in ipairs(GetPlayers()) do
        local playerId = tonumber(playerIdValue)
        if playerId then
            if audience.notifyJobs and listContains(notifyJobs, getJob(playerId)) then
                recipients[playerId] = true
            end
            if audience.admins and isAdmin(playerId) then
                recipients[playerId] = true
            end
            if audience.nearbyPlayers then
                local ped = GetPlayerPed(playerId)
                if ped > 0 and #(GetEntityCoords(ped) - detector.coords) <= Config.NotificationRadius then
                    recipients[playerId] = true
                end
            end
        end
    end

    for recipient in pairs(recipients) do
        TriggerClientEvent('rs_metal_scanner:client:detectionAlert', recipient, playerName, Config.ShowDetectedItems and found or nil)
    end
end

lib.callback.register('rs_metal_scanner:server:scanPlayer', function(source, target)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return { ok = false, error = 'unknown_player' } end
    if not hasItem(source, Config.HandScannerItem) then return { ok = false, error = 'no_scanner' } end
    if playerDistance(source, target) > Config.ScanDistance + 0.35 then return { ok = false, error = 'scan_too_far' } end

    local now = GetGameTimer()
    if manualCooldowns[source] and now - manualCooldowns[source] < Config.ScanServerCooldown then
        return { ok = false, error = 'scan_cancelled' }
    end
    manualCooldowns[source] = now

    local found = scanInventory(target)
    return { ok = true, detected = #found > 0, items = Config.ShowDetectedItems and found or nil }
end)

lib.callback.register('rs_metal_scanner:server:getDetectors', function(source)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end
    return { ok = true, detectors = detectorList() }
end)

lib.callback.register('rs_metal_scanner:server:createDetector', function(source, input)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end
    local detector, errorKey = validateDetector(input)
    if not detector then return { ok = false, error = errorKey } end

    detector.created_by = getIdentifier(source)
    if detector.persistent then
        detector.id = MySQL.insert.await([[
            INSERT INTO `metal_scanners`
                (`name`, `type`, `coords`, `heading`, `radius`, `cooldown`, `spawn_model`, `active`, `job_restriction`, `notify_jobs`, `ignored_jobs`, `trigger_dispatch`, `created_by`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            detector.name, detector.type, json.encode(detector.coords), detector.heading, detector.radius,
            detector.cooldown, detector.spawn_model and 1 or 0, detector.active and 1 or 0,
            json.encode(detector.job_restriction), json.encode(detector.notify_jobs), json.encode(detector.ignored_jobs),
            detector.trigger_dispatch and 1 or 0, detector.created_by
        })
        if not detector.id then return { ok = false, error = 'server_error' } end
    else
        detector.id = temporaryId
        temporaryId = temporaryId - 1
    end

    detectors[detector.id] = detector
    syncDetectors()
    return { ok = true, detector = serialiseDetector(detector) }
end)

lib.callback.register('rs_metal_scanner:server:updateDetector', function(source, id, input)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end
    id = tonumber(id)
    local existing = id and detectors[id]
    if not existing then return { ok = false, error = 'server_error' } end

    input.persistent = existing.persistent
    local detector, errorKey = validateDetector(input, id)
    if not detector then return { ok = false, error = errorKey } end
    detector.id, detector.created_by = id, existing.created_by

    if detector.persistent then
        local changed = MySQL.update.await([[
            UPDATE `metal_scanners` SET
                `name` = ?, `type` = ?, `coords` = ?, `heading` = ?, `radius` = ?, `cooldown` = ?,
                `spawn_model` = ?, `active` = ?, `job_restriction` = ?, `notify_jobs` = ?, `ignored_jobs` = ?, `trigger_dispatch` = ?
            WHERE `id` = ?
        ]], {
            detector.name, detector.type, json.encode(detector.coords), detector.heading, detector.radius,
            detector.cooldown, detector.spawn_model and 1 or 0, detector.active and 1 or 0,
            json.encode(detector.job_restriction), json.encode(detector.notify_jobs), json.encode(detector.ignored_jobs),
            detector.trigger_dispatch and 1 or 0, id
        })
        if changed == nil then return { ok = false, error = 'server_error' } end
    end

    detectors[id] = detector
    detectorCooldowns[id] = nil
    syncDetectors()
    return { ok = true, detector = serialiseDetector(detector) }
end)

lib.callback.register('rs_metal_scanner:server:deleteDetector', function(source, id)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end
    id = tonumber(id)
    local detector = id and detectors[id]
    if not detector then return { ok = false, error = 'server_error' } end
    if detector.persistent then
        MySQL.query.await('DELETE FROM `metal_scanners` WHERE `id` = ?', { id })
    end
    detectors[id], detectorCooldowns[id] = nil, nil
    syncDetectors()
    return { ok = true }
end)

lib.callback.register('rs_metal_scanner:server:toggleDetector', function(source, id)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end
    id = tonumber(id)
    local detector = id and detectors[id]
    if not detector then return { ok = false, error = 'server_error' } end
    detector.active = not detector.active
    if detector.persistent then
        MySQL.update.await('UPDATE `metal_scanners` SET `active` = ? WHERE `id` = ?', { detector.active and 1 or 0, id })
    end
    detectorCooldowns[id] = nil
    syncDetectors()
    return { ok = true, active = detector.active }
end)

lib.callback.register('rs_metal_scanner:server:refreshDetectors', function(source)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end
    loadDetectors()
    syncDetectors()
    return { ok = true }
end)

RegisterNetEvent('rs_metal_scanner:server:enteredDetector', function(id)
    local source = source
    id = tonumber(id)
    local detector = id and detectors[id]
    if not detector or not detector.active then return end

    local ped = GetPlayerPed(source)
    if ped <= 0 or not isInsideDetectorBox(GetEntityCoords(ped), detector, 0.75) then return end

    local job = getJob(source)
    if #detector.job_restriction > 0 and not listContains(detector.job_restriction, job) then return end
    if listContains(detector.ignored_jobs, job) or Config.IgnoredJobs[job or ''] or Config.BlacklistedJobs[job or ''] then return end

    local now = GetGameTimer()
    detectorCooldowns[id] = detectorCooldowns[id] or {}
    local lastDetection = detectorCooldowns[id][source]
    if lastDetection and now - lastDetection < detector.cooldown then return end
    detectorCooldowns[id][source] = now

    local found = scanInventory(source)
    if #found == 0 then return end

    local playerName = getPlayerNameSafe(source)
    local logDetections = (ServerConfig and ServerConfig.LogDetections ~= nil and ServerConfig.LogDetections) or (Config.LogDetections ~= false)
    if logDetections then
        local items = {}
        for i = 1, #found do items[#items + 1] = ('%s x%s'):format(found[i].name, found[i].count) end
        print(('[%s] Detector "%s" (#%s) detected %s (%s): %s'):format(
            RESOURCE, detector.name, detector.id, playerName, source, table.concat(items, ', ')
        ))
    end

    if alarmModeIncludes('beep_only') then
        TriggerClientEvent('rs_metal_scanner:client:detectorAlarm', -1, serialiseDetector(detector), source)
    end
    if alarmModeIncludes('notify_only') then
        notifyDetection(detector, source, found)
    end
    sendWebhook(detector, source, found)
    sendDispatch(detector, source, found)
end)

RegisterNetEvent('rs_metal_scanner:server:requestSync', function()
    syncDetectors(source)
end)

RegisterCommand('metalscanner', function(source)
    if source == 0 then
        print(('[%s] This command must be used in-game.'):format(RESOURCE))
        return
    end
    if not isAdmin(source) then
        TriggerClientEvent('rs_metal_scanner:client:notify', source, 'no_permission', 'error')
        return
    end
    TriggerClientEvent('rs_metal_scanner:client:openCreator', source)
end, false)

RegisterNetEvent('rs_metal_scanner:server:syncTargetAnimation', function(targetServerId, play)
    local src = source
    if not targetServerId or type(targetServerId) ~= 'number' then return end

    local dist = playerDistance(src, targetServerId)
    if dist > Config.ScanDistance + 2.0 then return end

    TriggerClientEvent('rs_metal_scanner:client:playTargetAnimation', targetServerId, play)
end)

AddEventHandler('playerDropped', function()
    manualCooldowns[source] = nil
    for _, cooldown in pairs(detectorCooldowns) do cooldown[source] = nil end
end)

MySQL.ready(function()
    initialiseFramework()
    pcall(function()
        MySQL.query.await('ALTER TABLE `metal_scanners` ADD COLUMN `trigger_dispatch` TINYINT(1) NOT NULL DEFAULT 1')
    end)
    loadDetectors()
    syncDetectors()
end)
