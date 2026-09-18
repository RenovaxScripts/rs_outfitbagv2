local detectors = {}
local zones = {}
local detectorProps = {}
local scannerProp
local scannerBusy = false

local function T(key, ...)
    local dictionary = Locales[Config.Locale] or Locales.en or {}
    local value = dictionary[key] or key
    if select('#', ...) > 0 then
        return value:format(...)
    end
    return value
end

local function notify(key, notifyType, ...)
    lib.notify({
        title = T('creator_title'),
        description = T(key, ...),
        type = notifyType or 'inform'
    })
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if Config.Debug then
        print(("[DEBUG] Requesting model: %s (hash: %s)"):format(model, hash))
    end
    if not IsModelInCdimage(hash) then
        if Config.Debug then
            print(("[DEBUG] Model '%s' (hash: %s) is NOT in Cdimage. Check if it is streamed or spelled correctly."):format(model, hash))
        end
        return nil
    end
    if not IsModelValid(hash) then
        if Config.Debug then
            print(("[DEBUG] Model '%s' (hash: %s) is NOT a valid model. Check if it is streamed or spelled correctly."):format(model, hash))
        end
        return nil
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then
            if Config.Debug then
                print(("[DEBUG] Model '%s' (hash: %s) timed out loading after 5 seconds."):format(model, hash))
            end
            return nil
        end
        Wait(0)
    end
    if Config.Debug then
        print(("[DEBUG] Model '%s' (hash: %s) loaded successfully."):format(model, hash))
    end
    return hash
end

local function loadAnimDict(dict)
    if Config.Debug then
        print(("[DEBUG] Requesting animation dictionary: %s"):format(dict))
    end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then
            if Config.Debug then
                print(("[DEBUG] Animation dictionary '%s' timed out loading after 5 seconds."):format(dict))
            end
            return false
        end
        Wait(0)
    end
    if Config.Debug then
        print(("[DEBUG] Animation dictionary '%s' loaded successfully."):format(dict))
    end
    return true
end

local function deleteEntitySafe(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
end

local function removeDetector(id)
    if zones[id] then
        zones[id]:remove()
        zones[id] = nil
    end
    deleteEntitySafe(detectorProps[id])
    detectorProps[id] = nil
end

local function createDetector(detector)
    local id = tonumber(detector.id)
    if not id or not detector.active then return end

    local coords = vec3(detector.coords.x + 0.0, detector.coords.y + 0.0, detector.coords.z + 0.0)

    if detector.type == 'model' and detector.spawn_model then
        CreateThread(function()
            local model = loadModel(Config.WalkthroughDetectorModel)
            if not model or not detectors[id] or not detectors[id].active then
                if Config.Debug then notify('model_failed', 'error') end
                return
            end

            local object = CreateObjectNoOffset(
                model,
                coords.x,
                coords.y,
                coords.z + Config.DetectorPropZOffset,
                false,
                false,
                false
            )
            SetEntityHeading(object, detector.heading + 0.0)
            FreezeEntityPosition(object, true)
            SetEntityInvincible(object, true)
            SetEntityCollision(object, true, true)
            detectorProps[id] = object
            SetModelAsNoLongerNeeded(model)
        end)
    end

    zones[id] = lib.zones.box({
        coords = coords,
        size = vec3((detector.radius + 0.0) * 2.0, Config.BoxZoneDepth, Config.BoxZoneHeight),
        rotation = detector.heading + 0.0,
        debug = Config.Debug,
        onEnter = function()
            TriggerServerEvent('rs_metal_scanner:server:enteredDetector', id)
        end
    })
end

local function rebuildDetectors(list)
    for id in pairs(zones) do removeDetector(id) end
    for id in pairs(detectorProps) do removeDetector(id) end
    detectors = {}

    for i = 1, #list do
        local detector = list[i]
        local id = tonumber(detector.id)
        if id then
            detector.id = id
            detectors[id] = detector
            createDetector(detector)
        end
    end
end

local function cleanupHandScanner()
    local ped = cache.ped
    if Config.HandScannerAnimation and Config.HandScannerAnimation.dict then
        StopAnimTask(ped, Config.HandScannerAnimation.dict, Config.HandScannerAnimation.clip, 1.0)
    end
    deleteEntitySafe(scannerProp)
    scannerProp = nil
    scannerBusy = false
end

local function itemList(items)
    local values = {}
    for i = 1, #(items or {}) do
        values[#values + 1] = ('%s x%s'):format(items[i].name, items[i].count)
    end
    return table.concat(values, ', ')
end

local function scanPlayer(entity)
    if scannerBusy or not entity or not DoesEntityExist(entity) then return end

    local isNpc = false
    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
    local target
    if playerIndex == -1 then
        if Config.Debug then
            isNpc = true
        else
            return
        end
    else
        target = GetPlayerServerId(playerIndex)
    end

    local hasScanner = 0
    if GetResourceState('nord_inventory') == 'started' or Config.Inventory == 'nord_inventory' or Config.Inventory == 'nord' then
        hasScanner = exports.nord_inventory:GetItemCount(Config.HandScannerItem) or exports.nord_inventory:Search('count', Config.HandScannerItem) or 0
    else
        hasScanner = exports[Config.Inventory]:Search('count', Config.HandScannerItem) or 0
    end
    if (tonumber(hasScanner) or 0) < 1 then
        notify('no_scanner', 'error')
        return
    end

    if #(GetEntityCoords(cache.ped) - GetEntityCoords(entity)) > Config.ScanDistance + 0.1 then
        notify('scan_too_far', 'error')
        return
    end

    scannerBusy = true
    notify('scan_start', 'inform')

    local model = loadModel(Config.HandScannerProp)
    if not model then
        if Config.Debug then
            print(("[DEBUG] Primary hand scanner prop '%s' failed to load. Trying fallback prop '%s'."):format(Config.HandScannerProp, Config.HandScannerFallbackProp))
        end
        model = loadModel(Config.HandScannerFallbackProp)
    end

    local animation = Config.HandScannerAnimation
    local animLoaded = loadAnimDict(animation.dict)

    if not model or not animLoaded then
        if Config.Debug then
            print(("[DEBUG] Scan player failed setup. Model Loaded: %s, Anim Dict Loaded: %s"):format(tostring(model ~= nil), tostring(animLoaded)))
        end
        cleanupHandScanner()
        notify('server_error', 'error')
        return
    end

    local ped = cache.ped
    local attachment = Config.HandScannerAttachment
    local coords = GetEntityCoords(ped)
    scannerProp = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(
        scannerProp, ped, GetPedBoneIndex(ped, attachment.bone),
        attachment.position.x, attachment.position.y, attachment.position.z,
        attachment.rotation.x, attachment.rotation.y, attachment.rotation.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)

    if isNpc then
        local anim = Config.TargetScannerAnimation
        if anim and anim.enabled then
            loadAnimDict(anim.dict)
            TaskPlayAnim(entity, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag, 0, false, false, false)
        end
    else
        TriggerServerEvent('rs_metal_scanner:server:syncTargetAnimation', target, true)
    end

    local completed = lib.progressBar({
        duration = Config.ScanDuration,
        label = T('scan_start'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, sprint = true },
        anim = { dict = animation.dict, clip = animation.clip, flag = animation.flag }
    })

    local stillClose = DoesEntityExist(entity)
        and #(GetEntityCoords(cache.ped) - GetEntityCoords(entity)) <= Config.ScanDistance + 0.35
    cleanupHandScanner()

    if isNpc then
        local anim = Config.TargetScannerAnimation
        if anim and anim.enabled then
            StopAnimTask(entity, anim.dict, anim.clip, 1.0)
        end
    else
        TriggerServerEvent('rs_metal_scanner:server:syncTargetAnimation', target, false)
    end

    if not completed then
        notify('scan_cancelled', 'error')
        return
    end
    if not stillClose then
        notify('scan_too_far', 'error')
        return
    end

    if isNpc then
        notify('scan_clear', 'success')
        if Config.Debug then
            print("[DEBUG] NPC scanned successfully (simulated clear result).")
        end
        return
    end

    local result = lib.callback.await('rs_metal_scanner:server:scanPlayer', false, target)
    if not result or not result.ok then
        notify(result and result.error or 'server_error', 'error')
        return
    end

    if result.detected then
        notify('scan_detected', 'error')
        if Config.HandScannerBeep then
            local plyCoords = GetEntityCoords(cache.ped)
            local soundId = GetSoundId()
            PlaySoundFromCoord(soundId, Config.BeepSound.name, plyCoords.x, plyCoords.y, plyCoords.z, Config.BeepSound.set, false, 0, false)
            SetVariableOnSound(soundId, 'Volume', Config.BeepSound.volume)
            CreateThread(function()
                Wait(1000)
                StopSound(soundId)
                ReleaseSoundId(soundId)
            end)
        end
        if Config.ShowDetectedItems and result.items and #result.items > 0 then
            lib.notify({ title = T('creator_title'), description = T('found_items', itemList(result.items)), type = 'warning' })
        end
    else
        notify('scan_clear', 'success')
    end
end

local function splitCsv(value)
    local result, seen = {}, {}
    for entry in tostring(value or ''):gmatch('[^,]+') do
        entry = entry:lower():gsub('^%s*(.-)%s*$', '%1')
        if entry ~= '' and not seen[entry] then
            seen[entry] = true
            result[#result + 1] = entry
        end
    end
    return result
end

local function joinList(value)
    return type(value) == 'table' and table.concat(value, ', ') or ''
end

local function detectorForm(kind, existing)
    local currentCoords = GetEntityCoords(cache.ped)
    local values = existing or {
        name = '',
        coords = { x = currentCoords.x, y = currentCoords.y, z = currentCoords.z },
        heading = GetEntityHeading(cache.ped),
        radius = Config.DefaultRadius,
        cooldown = Config.DefaultCooldown,
        job_restriction = {},
        notify_jobs = {},
        ignored_jobs = {},
        trigger_dispatch = true,
        spawn_model = kind == 'model',
        active = true,
        persistent = true
    }

    local rows = {
        { type = 'input', label = T('form_name'), required = true, default = values.name, min = 1, max = 100 },
        { type = 'number', label = T('form_coord_x'), required = true, default = values.coords.x, precision = 3 },
        { type = 'number', label = T('form_coord_y'), required = true, default = values.coords.y, precision = 3 },
        { type = 'number', label = T('form_coord_z'), required = true, default = values.coords.z, precision = 3 },
        { type = 'number', label = T('form_heading'), required = true, default = values.heading, min = 0, max = 360, precision = 1 },
        { type = 'number', label = T('form_radius'), required = true, default = values.radius, min = 0.1, max = Config.MaximumRadius, precision = 2 },
        { type = 'number', label = T('form_cooldown'), required = true, default = values.cooldown, min = Config.MinimumCooldown, precision = 0 },
        { type = 'input', label = T('form_job_restriction'), default = joinList(values.job_restriction) },
        { type = 'input', label = T('form_notify_jobs'), default = joinList(values.notify_jobs) },
        { type = 'input', label = T('form_ignored_jobs'), default = joinList(values.ignored_jobs) },
        { type = 'checkbox', label = T('trigger_dispatch_label'), description = T('trigger_dispatch_desc'), checked = values.trigger_dispatch ~= false }
    }

    if kind == 'model' then
        rows[#rows + 1] = { type = 'checkbox', label = T('form_spawn_model'), checked = values.spawn_model ~= false }
    end
    if not existing then
        rows[#rows + 1] = { type = 'checkbox', label = T('form_save_db'), checked = true }
    end
    rows[#rows + 1] = { type = 'checkbox', label = T('form_active'), checked = values.active ~= false }

    local input = lib.inputDialog(existing and T('edit') or (kind == 'model' and T('create_model') or T('create_zone')), rows)
    if not input then return nil end

    local triggerDispatch = input[11] == true
    local index = 11

    local spawnModel = false
    if kind == 'model' then
        index = index + 1
        spawnModel = input[index] == true
    end
    local persistent = existing and existing.persistent ~= false or true
    if not existing then
        index = index + 1
        persistent = input[index] == true
    end
    index = index + 1

    return {
        name = input[1],
        type = kind,
        coords = { x = tonumber(input[2]), y = tonumber(input[3]), z = tonumber(input[4]) },
        heading = tonumber(input[5]),
        radius = tonumber(input[6]),
        cooldown = tonumber(input[7]),
        job_restriction = splitCsv(input[8]),
        notify_jobs = splitCsv(input[9]),
        ignored_jobs = splitCsv(input[10]),
        trigger_dispatch = triggerDispatch,
        spawn_model = spawnModel,
        persistent = persistent,
        active = input[index] == true
    }
end

local openMainMenu, openManagement, openDetectorMenu

local function createNewDetector(kind)
    local input = detectorForm(kind)
    if not input then return end
    local result = lib.callback.await('rs_metal_scanner:server:createDetector', false, input)
    if result and result.ok then
        notify('detector_created', 'success')
    else
        notify(result and result.error or 'server_error', 'error')
    end
    openMainMenu()
end

openDetectorMenu = function(detector)
    lib.registerContext({
        id = 'rs_metal_scanner_detector_actions',
        title = ('%s (#%s)'):format(detector.name, detector.id),
        menu = 'rs_metal_scanner_management',
        options = {
            {
                title = T('teleport'), icon = 'location-dot',
                onSelect = function()
                    SetEntityCoords(cache.ped, detector.coords.x, detector.coords.y, detector.coords.z + 0.5, false, false, false, false)
                end
            },
            {
                title = T('edit'), icon = 'pen-to-square',
                onSelect = function()
                    local input = detectorForm(detector.type, detector)
                    if not input then return end
                    local result = lib.callback.await('rs_metal_scanner:server:updateDetector', false, detector.id, input)
                    notify(result and result.ok and 'detector_updated' or (result and result.error or 'server_error'), result and result.ok and 'success' or 'error')
                    openManagement()
                end
            },
            {
                title = T('toggle'),
                description = detector.active and T('detector_disabled') or T('detector_enabled'),
                icon = detector.active and 'toggle-on' or 'toggle-off',
                onSelect = function()
                    local result = lib.callback.await('rs_metal_scanner:server:toggleDetector', false, detector.id)
                    if result and result.ok then
                        notify(result.active and 'detector_enabled' or 'detector_disabled', 'success')
                    else
                        notify(result and result.error or 'server_error', 'error')
                    end
                    openManagement()
                end
            },
            {
                title = T('delete'), icon = 'trash', iconColor = '#ef4444',
                onSelect = function()
                    local answer = lib.alertDialog({
                        header = T('delete'), content = T('confirm_delete', detector.name), centered = true, cancel = true
                    })
                    if answer ~= 'confirm' then return end
                    local result = lib.callback.await('rs_metal_scanner:server:deleteDetector', false, detector.id)
                    notify(result and result.ok and 'detector_deleted' or (result and result.error or 'server_error'), result and result.ok and 'success' or 'error')
                    openManagement()
                end
            }
        }
    })
    lib.showContext('rs_metal_scanner_detector_actions')
end

openManagement = function()
    local result = lib.callback.await('rs_metal_scanner:server:getDetectors', false)
    if not result or not result.ok then
        notify(result and result.error or 'server_error', 'error')
        return
    end

    local options = {}
    for i = 1, #result.detectors do
        local detector = result.detectors[i]
        options[#options + 1] = {
            title = detector.name,
            description = ('#%s · %s · %.1fm · %s · Dispatch: %s'):format(
                detector.id, detector.type == 'model' and 'model' or 'zone', detector.radius, detector.active and 'ON' or 'OFF', detector.trigger_dispatch and T('dispatch_yes') or T('dispatch_no')
            ),
            icon = detector.type == 'model' and 'person-through-window' or 'circle-dot',
            iconColor = detector.active and '#22c55e' or '#ef4444',
            arrow = true,
            onSelect = function() openDetectorMenu(detector) end
        }
    end
    if #options == 0 then options[1] = { title = T('no_detectors'), disabled = true } end

    lib.registerContext({
        id = 'rs_metal_scanner_management',
        title = T('manage'),
        menu = 'rs_metal_scanner_main',
        options = options
    })
    lib.showContext('rs_metal_scanner_management')
end

openMainMenu = function()
    lib.registerContext({
        id = 'rs_metal_scanner_main',
        title = T('creator_title'),
        options = {
            { title = T('create_model'), icon = 'archway', onSelect = function() createNewDetector('model') end },
            { title = T('create_zone'), icon = 'circle-dot', onSelect = function() createNewDetector('zone') end },
            { title = T('manage'), icon = 'list-check', arrow = true, onSelect = openManagement },
            {
                title = T('refresh'), icon = 'rotate',
                onSelect = function()
                    local result = lib.callback.await('rs_metal_scanner:server:refreshDetectors', false)
                    notify(result and result.ok and 'detectors_refreshed' or (result and result.error or 'server_error'), result and result.ok and 'success' or 'error')
                    openMainMenu()
                end
            }
        }
    })
    lib.showContext('rs_metal_scanner_main')
end

RegisterNetEvent('rs_metal_scanner:client:syncDetectors', rebuildDetectors)

RegisterNetEvent('rs_metal_scanner:client:notify', function(key, notifyType)
    notify(key, notifyType)
end)

RegisterNetEvent('rs_metal_scanner:client:openCreator', openMainMenu)

RegisterNetEvent('rs_metal_scanner:client:triggerDispatch', function(detector, found)
    if SendClientDispatch then
        SendClientDispatch(detector, found)
    end
end)

RegisterNetEvent('rs_metal_scanner:client:detectionAlert', function(playerName, items)
    lib.notify({ title = T('creator_title'), description = T('detector_alert', playerName), type = 'warning' })
    if items and #items > 0 then
        lib.notify({ title = T('creator_title'), description = T('found_items', itemList(items)), type = 'warning' })
    end
end)

RegisterNetEvent('rs_metal_scanner:client:detectorAlarm', function(detector, triggeringSource)
    local coords = vec3(detector.coords.x, detector.coords.y, detector.coords.z)
    if #(GetEntityCoords(cache.ped) - coords) <= Config.BeepSound.distance then
        if Config.BeepSound.enabled then
            local soundId = GetSoundId()
            PlaySoundFromCoord(soundId, Config.BeepSound.name, coords.x, coords.y, coords.z, Config.BeepSound.set, false, 0, false)
            SetVariableOnSound(soundId, 'Volume', Config.BeepSound.volume)
            CreateThread(function()
                Wait(1500)
                StopSound(soundId)
                ReleaseSoundId(soundId)
            end)
        end
    end

    if triggeringSource == GetPlayerServerId(PlayerId()) then
        notify('detector_beep', 'error')
    end

    local prop = detectorProps[tonumber(detector.id)]
    if Config.DetectorFlash and Config.DetectorFlash.enabled then
        CreateThread(function()
            local flashes = Config.DetectorFlash.flashes or 4
            local interval = Config.DetectorFlash.interval or 150
            local enableRedLight = Config.DetectorFlash.enableRedLight ~= false

            for _ = 1, flashes do
                if prop and DoesEntityExist(prop) then
                    SetEntityAlpha(prop, 100, false)
                end

                local timer = GetGameTimer() + interval
                while GetGameTimer() < timer do
                    if enableRedLight then
                        DrawLightWithRange(coords.x, coords.y, coords.z + 1.0, 255, 0, 0, 3.5, 5.0)
                    end
                    Wait(0)
                end

                if prop and DoesEntityExist(prop) then
                    SetEntityAlpha(prop, 255, false)
                end
                Wait(interval)
            end

            if prop and DoesEntityExist(prop) then
                ResetEntityAlpha(prop)
            end
        end)
    end

    if OnClientDetectorAlarm then
        OnClientDetectorAlarm(detector, triggeringSource)
    end
end)

CreateThread(function()
    exports[Config.Target]:addGlobalPlayer({
        {
            name = 'rs_metal_scanner_scan_player',
            icon = 'fa-solid fa-magnifying-glass',
            label = T('target_scan'),
            items = Config.HandScannerItem,
            distance = Config.ScanDistance,
            canInteract = function(entity, distance)
                return not scannerBusy and entity ~= cache.ped and distance <= Config.ScanDistance
            end,
            onSelect = function(data) scanPlayer(data.entity) end
        }
    })

    if Config.Debug then
        exports[Config.Target]:addGlobalPed({
            {
                name = 'rs_metal_scanner_scan_ped_debug',
                icon = 'fa-solid fa-magnifying-glass',
                label = T('target_scan') .. " (NPC Debug)",
                items = Config.HandScannerItem,
                distance = Config.ScanDistance,
                canInteract = function(entity, distance)
                    if NetworkGetPlayerIndexFromPed(entity) ~= -1 then return false end
                    return not scannerBusy and entity ~= cache.ped and distance <= Config.ScanDistance
                end,
                onSelect = function(data) scanPlayer(data.entity) end
            }
        })
    end

    Wait(500)
    TriggerServerEvent('rs_metal_scanner:server:requestSync')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupHandScanner()
    for id in pairs(zones) do removeDetector(id) end
    for id in pairs(detectorProps) do removeDetector(id) end
    exports[Config.Target]:removeGlobalPlayer('rs_metal_scanner_scan_player')
    if Config.Debug then
        exports[Config.Target]:removeGlobalPed('rs_metal_scanner_scan_ped_debug')
    end
end)

local targetPlayingAnim = false
RegisterNetEvent('rs_metal_scanner:client:playTargetAnimation', function(play)
    local ped = cache.ped
    if play then
        local anim = Config.TargetScannerAnimation
        if anim and anim.enabled then
            loadAnimDict(anim.dict)
            TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag, 0, false, false, false)
            targetPlayingAnim = true
        end
    else
        if targetPlayingAnim then
            local anim = Config.TargetScannerAnimation
            StopAnimTask(ped, anim.dict, anim.clip, 1.0)
            targetPlayingAnim = false
        end
    end
end)
