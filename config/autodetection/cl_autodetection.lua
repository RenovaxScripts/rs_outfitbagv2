if Config.Framework == 'auto' then
    print("^3[WARNING]^0 Framework detection is set to 'auto'. Check if it is set correctly in config.lua.")
    CreateThread(function()
        if GetResourceState('qb-core') == 'started' then
            QBCore = exports['qb-core']:GetCoreObject()
            Config.Framework = 'qb'
            print("^2[INFO]^0 Framework detection: QBcore")
        elseif GetResourceState('es_extended') == 'started' then
            ESX = exports["es_extended"]:getSharedObject()
            Config.Framework = 'esx'
            print("^2[INFO]^0 Framework detection: ESX")
        end
    end)
end

if Config.Notify == 'auto' then
    print("^3[WARNING]^0 Notification detection is set to 'auto'. Check if it is set correctly in config.lua.")
    CreateThread(function()
        if GetResourceState('ox_lib') == 'started' then
           Config.Notify = 'ox'
           print("^2[INFO]^0 Notification detection: ox_lib")
        elseif GetResourceState('qb-core') == 'started' then
            Config.Notify = 'qb'
            print("^2[INFO]^0 Notification detection: qb notify")
        elseif GetResourceState('es_extended') == 'started' then
            Config.Notify = 'esx'
            print("^2[INFO]^0 Notification detection: esx notify")
        else
            Config.Notify = 'custom'
            print("^3[WARNING]^0 Notifications were not detected. Custom mode is being used.")
        end
    end)
end

if Config.InteractionType == 'target' then
if Config.Target == 'auto' then
    print("^3[WARNING]^0 Target detection is set to 'auto'. Check if it is set correctly in config.lua.")
    CreateThread(function()
        if GetResourceState('ox_target') == 'started' then
            Config.Target = 'ox_target'
            print("^2[INFO]^0 Target detection: ox_target")
        elseif GetResourceState('qtarget') == 'started' then
            Config.Target = 'qtarget'
            print("^2[INFO]^0 Target detection: qtarget")
        elseif GetResourceState('qb-target') == 'started' then
            Config.Target = 'qb_target'
            print("^2[INFO]^0 Target detection: qb_target")
        else
            Config.Target = 'custom'
            print("^3[WARNING]^0 Target system not detected. Custom mode is being used.")
        end
        InteractionTarget()
    end)
end
end


if Config.InteractionType == 'textui' then
if Config.TextUI == 'auto' then
    print("^3[WARNING]^0 Textui detection is set to 'auto'. Check if it is set correctly in config.lua.")
    CreateThread(function()
        if GetResourceState('ox_lib') == 'started' then
            Config.TextUI = 'ox_lib'
            print("^2[INFO]^0 Textui detection: ox_lib")
        elseif GetResourceState('es_extended') == 'started' then
            Config.TextUI = 'esx_textui'
            print("^2[INFO]^0 Textui detection: esx_textui")
        else
            Config.TextUI = 'custom'
            print("^3[WARNING]^0 Textui system not detected. Custom mode is used.")
        end
        InteractionTextui()
    end)
end

end


CreateThread(function()
    if Config.InteractionType == 'target' then
        InteractionTarget()
    elseif Config.InteractionType == 'textui' then
        InteractionTextui() 
    elseif Config.InteractionType == 'custom' then
        InteractionCustom()
    else
        print("^3[WARNING]^0 The interaction type was not recognized.")
    end
end)


if Config.Inventory == 'auto' then
CreateThread(function()
        print("^3[WARNING]^0 Inventory is set to 'auto'. Detecting...")
        if GetResourceState('ox_inventory') == 'started' then
            Config.Inventory = 'ox'
            print("^2[INFO]^0 Inventory detection: ox_inventory")
        elseif GetResourceState('qs-inventory') == 'started' then
            Config.Inventory = 'qs'
            print("^2[INFO]^0 Inventory detection: qs-inventory")
        elseif GetResourceState('codem-inventory') == 'started' then
            Config.Inventory = 'codem'
            print("^2[INFO]^0 Inventory detection: codem-inventory")
        else
            Config.Inventory = 'custom'
            print("^3[WARNING]^0 Inventory not detected. Custom mode is being used.")
        end
end)
end