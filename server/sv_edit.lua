-- Server-side dispatch
-- cd_dispatch is handled in cl_edit.lua (requires client-side GetPlayerInfo)

--- Sends dispatch notification from the server side.
--- Supports ps-dispatch, qs-dispatch, and custom event systems.
--- cd_dispatch is skipped here because it requires client-side GetPlayerInfo().
--- @param detector table Detector object (contains: name, coords, trigger_dispatch, notify_jobs, etc.)
--- @param source number Server ID of the player who triggered the detection
--- @param found table List of detected metal items ({ name = string, count = number }[])
function SendServerDispatch(detector, source, found)
    if not Config.Dispatch or not Config.Dispatch.enabled then return end
    if detector and detector.trigger_dispatch == false then return end

    local T = function(key, ...)
        local dictionary = Locales[Config.Locale] or Locales.en or {}
        local value = dictionary[key] or key
        if select('#', ...) > 0 then return value:format(...) end
        return value
    end

    local ped = GetPlayerPed(source)
    local coords = (ped > 0) and GetEntityCoords(ped) or (detector and detector.coords or vector3(0.0, 0.0, 0.0))
    local detectorName = (detector and detector.name) or T('unknown_location')

    local title = T('dispatch_alert_title')
    local description = T('dispatch_alert_message', detectorName)
    local jobs = (detector and detector.notify_jobs and #detector.notify_jobs > 0) 
        and detector.notify_jobs 
        or (Config.Dispatch.jobs or { 'police', 'sheriff' })

    local system = Config.Dispatch.system or 'cd_dispatch'

    if system == 'cd_dispatch' or system == 'none' then
        return
    end


    -- ps-dispatch
    if system == 'ps-dispatch' then
        TriggerEvent('ps-dispatch:server:notify', {
            dispatchcodename = "metaldetector",
            dispatchCode = "10-90",
            firstStreet = detectorName,
            priority = 2,
            origin = { x = coords.x, y = coords.y, z = coords.z },
            dispatchMessage = description,
            job = jobs
        })

    -- qs-dispatch
    elseif system == 'qs-dispatch' then
        TriggerServerEvent('qs-dispatch:server:CreateDispatchCall', {
            job = jobs,
            callIsPriority = true,
            callCode = { code = '10-90', snippet = title },
            message = description,
            flashes = false,
            location = coords
        })

    -- Custom event
    elseif system == 'custom' then
        TriggerEvent('rs_metal_scanner:server:customDispatch', {
            title = title,
            description = description,
            detector = detector,
            source = source,
            coords = coords,
            found = found,
            jobs = jobs
        })
    end
end
