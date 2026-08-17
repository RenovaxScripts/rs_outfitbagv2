local menuOpen = false
local ESX
local QBCore

local function fallbackNotify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function notify(message, notifyType)
    local notificationType = string.lower(tostring(Config.Notification or 'custom'))
    notifyType = notifyType or 'info'

    if notificationType == 'ox_lib' and GetResourceState('ox_lib') == 'started' then
        local ok = pcall(function()
            exports.ox_lib:notify({
                description = message,
                type = notifyType,
                duration = Config.NotificationDuration
            })
        end)
        if ok then return end
    end

    if (notificationType == 'qbx' or notificationType == 'qbox') and GetResourceState('qbx_core') == 'started' then
        local ok = pcall(function()
            exports.qbx_core:Notify(message, notifyType, Config.NotificationDuration)
        end)
        if ok then return end
    end

    if notificationType == 'esx' and GetResourceState('es_extended') == 'started' then
        local ok = pcall(function()
            ESX = ESX or exports['es_extended']:getSharedObject()
            ESX.ShowNotification(message)
        end)
        if ok then return end
    end

    if notificationType == 'qb' and GetResourceState('qb-core') == 'started' then
        local ok = pcall(function()
            QBCore = QBCore or exports['qb-core']:GetCoreObject()
            local qbType = notifyType == 'info' and 'primary' or notifyType
            QBCore.Functions.Notify(message, qbType, Config.NotificationDuration)
        end)
        if ok then return end
    end

    if notificationType == 'custom' and type(Config.CustomNotify) == 'function' then
        local ok = pcall(Config.CustomNotify, message, notifyType)
        if ok then return end
    end

    fallbackNotify(message)
end

local function closeMenu()
    if not menuOpen then return end

    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('rs_multijob:client:notify', function(message, notifyType)
    if type(message) ~= 'string' then return end
    notify(message, notifyType)
end)

RegisterNetEvent('rs_multijob:client:open', function(payload)
    if type(payload) ~= 'table' then return end

    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        payload = payload
    })
end)

RegisterNetEvent('rs_multijob:client:update', function(payload)
    if not menuOpen or type(payload) ~= 'table' then return end

    SendNUIMessage({
        action = 'update',
        payload = payload
    })
end)

RegisterNUICallback('close', function(_, callback)
    closeMenu()
    callback({ ok = true })
end)

RegisterNUICallback('activate', function(data, callback)
    if not menuOpen or type(data) ~= 'table' or type(data.job) ~= 'string' then
        callback({ ok = false })
        return
    end

    TriggerServerEvent('rs_multijob:server:activate', data.job)
    callback({ ok = true })
end)

RegisterNUICallback('remove', function(data, callback)
    if not menuOpen or type(data) ~= 'table' or type(data.job) ~= 'string' then
        callback({ ok = false })
        return
    end

    TriggerServerEvent('rs_multijob:server:remove', data.job)
    callback({ ok = true })
end)

RegisterNUICallback('toggleDuty', function(_, callback)
    if not menuOpen then
        callback({ ok = false })
        return
    end

    TriggerServerEvent('rs_multijob:server:toggleDuty')
    callback({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        menuOpen = false
        SetNuiFocus(false, false)
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close',
        immediate = true
    })
end)

RegisterCommand('toggle_multijob', function()
    if menuOpen then
        closeMenu()
    else
        ExecuteCommand(Config.Command or 'multijob')
    end
end, false)

if Config.Keybind and Config.Keybind ~= '' then
    RegisterKeyMapping('toggle_multijob', 'Otevřít Multijob Menu', 'keyboard', Config.Keybind)
end

exports('OpenMenu', function()
    ExecuteCommand(Config.Command or 'multijob')
end)

exports('CloseMenu', function()
    closeMenu()
end)

exports('ToggleDuty', function()
    TriggerServerEvent('rs_multijob:server:toggleDuty')
end)


