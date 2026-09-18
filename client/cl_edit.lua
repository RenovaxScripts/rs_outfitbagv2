-- Client-side dispatch & hooks
-- Edit this function to integrate your client-side dispatch system

--- Triggers client-side police dispatch notification when metal is detected.
--- @param detector table Detector object containing name, coords, trigger_dispatch, notify_jobs, etc.
--- @param found table List of detected metal items ({ name = string, count = number }[])
function SendClientDispatch(detector, found)
    if not Config.Dispatch or not Config.Dispatch.enabled then return end
    if detector and detector.trigger_dispatch == false then return end

    local system = Config.Dispatch.system or 'none'
    if system == 'none' then return end

    local T = function(key, ...)
        local dictionary = Locales[Config.Locale] or Locales.en or {}
        local value = dictionary[key] or key
        if select('#', ...) > 0 then return value:format(...) end
        return value
    end

    local detectorName = (detector and detector.name) or T('unknown_location')
    local title = T('dispatch_alert_title')
    local message = T('dispatch_alert_message', detectorName)

    local jobs = (detector and detector.notify_jobs and #detector.notify_jobs > 0) 
        and detector.notify_jobs 
        or (Config.Dispatch.jobs or { 'police', 'sheriff' })

    -- cd_dispatch
    if system == 'cd_dispatch' then
        local ok, data = pcall(function()
            return exports['cd_dispatch']:GetPlayerInfo()
        end)

        if ok and data then
            TriggerServerEvent('cd_dispatch:AddNotification', {
                job_table = jobs, 
                coords = data.coords,
                title = title,
                message = message, 
                flash = 0,
                unique_id = data.unique_id,
                sound = 1,
                blip = {
                    sprite = 431, 
                    scale = 1.2, 
                    colour = 3,
                    flashes = false, 
                    text = title,
                    time = 5,
                    radius = 0,
                }
            })
        else
            print("[rs_metal_scanner] ERROR: cd_dispatch export GetPlayerInfo failed.")
        end

    -- ps-dispatch (client side)
    elseif system == 'ps-dispatch-client' then
        exports['ps-dispatch']:CustomAlert({
            dispatchCode = "10-90",
            description = message,
            radius = 0,
            sprite = 431,
            color = 3,
            scale = 1.2,
            length = 3,
        })
    end
end

--- Hook called when a detector alarm is triggered on the client side.
--- @param detector table Detector object that was triggered
--- @param triggeringSource number Server ID of the player who triggered the alarm
function OnClientDetectorAlarm(detector, triggeringSource)
    -- Custom client-side alarm logic/effects can be added here
end
