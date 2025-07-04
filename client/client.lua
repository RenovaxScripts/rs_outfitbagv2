local ESX, QBCore
local outfitbags = {}
local framework = nil

function DebugPrint(text)
    if Config.Debug then print("[RS Outfit Bag | DEBUG] "..text) end
end


CreateThread(function()
    while Config.Framework == 'auto' do
        Wait(100)
    end

    if Config.Framework == "esx" then
        while ESX == nil do
            ESX = exports["es_extended"]:getSharedObject()
            Wait(100)
        end
        framework = 'esx'
        DebugPrint("[Outfit Bag] ESX loaded")
    elseif Config.Framework == "qb" then
        while QBCore == nil do
            QBCore = exports['qb-core']:GetCoreObject()
            Wait(100)
        end
        framework = 'qb'
        DebugPrint("[Outfit Bag] QBCore loaded")
    elseif Config.Framework == "custom" then
        framework = 'custom' -- don't remove this
        -- set your own framework
    else
        DebugPrint("[Outfit Bag] Invalid framework configuration")
    end
end)

RegisterNetEvent('rs_outfitbag:open')
AddEventHandler('rs_outfitbag:open', function()
    lib.registerContext({
        id = 'outfitbag_main_menu',
        title = Language.title,
        options = {
            {
                title = Language.saveoutfit,
                description = Language.savenowoutfit,
                icon = 'floppy-disk',
                onSelect = function()
                    if framework == "esx" then
                        ESX.TriggerServerCallback("rs_outfitbag:getOutfitCount", function(count)
                            if count >= Config.MaxOutfits then
                                if Config.Notify == 'esx' then
                                   Notify(Language.maxoutfits)
                                else
                                   Notify(Language.title, Language.maxoutfits, 'error')
                                end
                                
                                return
                            end

                            local input = lib.inputDialog(Language.saveoutfit, {
                                { type = "input", label = Language.nameoutfit, placeholder = Language.myoutfit }
                           })

                            if input and input[1] then
                                local ped = PlayerPedId()
                                local outfit = {
                                    model = GetEntityModel(ped),
                                    drawableVariations = {},
                                    propVariations = {}
                                }

                                for i = 0, 11 do
                                    table.insert(outfit.drawableVariations, {
                                        component = i,
                                        drawable = GetPedDrawableVariation(ped, i),
                                        texture = GetPedTextureVariation(ped, i),
                                        palette = GetPedPaletteVariation(ped, i)
                                    })
                                end

                                for i = 0, 7 do
                                    table.insert(outfit.propVariations, {
                                        component = i,
                                        drawable = GetPedPropIndex(ped, i),
                                        texture = GetPedPropTextureIndex(ped, i)
                                    })
                                end

                                TriggerServerEvent("rs_outfitbag:saveOutfit", input[1], outfit)
                               
                                if Config.Notify == 'esx' then
                                   Notify(Language.savedoutfit .. '\n' .. input[1])
                                else
                                   Notify(Language.title, Language.savedoutfit .. '\n' .. input[1], 'success')
                                end
                            end
                        end) 
                    elseif framework == "qb" then
                        QBCore.Functions.TriggerCallback("rs_outfitbag:getOutfitCount", function(count)
                            if count >= Config.MaxOutfits then
                                     Notify(Language.title, Language.maxoutfits, 'error')
                                return
                            end

                            local dialog = exports['qb-input']:ShowInput({
                                header = Language.saveoutfit,
                                submitText = Language.save,
                                inputs = {
                                    {
                                        type = 'text',
                                        isRequired = true,
                                        name = 'outfitName',
                                        text = Language.outfitname
                                    }
                                }
                            })

                            if dialog and dialog.outfitName then
                                local ped = PlayerPedId()
                                local outfit = {
                                    model = GetEntityModel(ped),
                                    drawableVariations = {},
                                    propVariations = {}
                                }

                                for i = 0, 11 do
                                    table.insert(outfit.drawableVariations, {
                                        component = i,
                                        drawable = GetPedDrawableVariation(ped, i),
                                        texture = GetPedTextureVariation(ped, i),
                                        palette = GetPedPaletteVariation(ped, i)
                                    })
                                end

                                for i = 0, 7 do
                                    table.insert(outfit.propVariations, {
                                        component = i,
                                        drawable = GetPedPropIndex(ped, i),
                                        texture = GetPedPropTextureIndex(ped, i)
                                    })
                                end
            
                                TriggerServerEvent("rs_outfitbag:saveOutfit", dialog.outfitName, outfit)
                                Notify(Language.title, Language.savedoutfit .. dialog.outfitName, 'success')
                            end
                        end)
                    elseif framework == "custom" then
                        -- Add your custom framework logic here
                    end
                end 
            },
            {
                title = Language.outfits,
                description = Language.showsavedoutfits,
                icon = 'shirt',
                onSelect = function()
                    TriggerEvent('rs_outfitbag:showOutfitList')
                end
            },
        }
    })

    lib.showContext('outfitbag_main_menu')
end)

RegisterNetEvent('rs_outfitbag:applyOutfit')
AddEventHandler('rs_outfitbag:applyOutfit', function(outfit)
    local ped = PlayerPedId()


    local model = outfit.model
    if model and IsModelValid(model) and not IsPedModel(ped, model) then
        local modelHash = tonumber(model)
        if not modelHash then
            modelHash = GetHashKey(model)
        end

        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Citizen.Wait(10)
        end

        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)
        ped = PlayerPedId()
    end


    if outfit.drawableVariations then
        for _, comp in pairs(outfit.drawableVariations) do
            SetPedComponentVariation(ped, comp.component, comp.drawable, comp.texture, comp.palette or 0)
        end
    end


    if outfit.propVariations then
        for _, prop in pairs(outfit.propVariations) do
            SetPedPropIndex(ped, prop.component, prop.drawable, prop.texture, true)
        end
    end

    
    if Config.Notify == 'esx' then
        Notify(Language.outfiton)
    else
        Notify(Language.title, Language.outfiton, 'success')
    end
end)


RegisterNetEvent('rs_outfitbag:showOutfitList')
AddEventHandler('rs_outfitbag:showOutfitList', function()
    if framework == "esx" then
        ESX.TriggerServerCallback("rs_outfitbag:getOutfits", function(outfits)
            if not outfits or #outfits == 0 then
                if Config.Notify == 'esx' then
                    Notify(Language.nooutfits)
                else
                    Notify(Language.title, Language.nooutfits, 'error')
                end
                return
            end

            local elements = {}

            for _, outfit in pairs(outfits) do
                table.insert(elements, {
                    title = outfit.name,
                    description = Language.moreoptions,
                    icon = "shirt",
                    menu = "outfit:" .. outfit.id
                })

                local options = {
                    {
                        title = Language.dressup,
                        icon = "tshirt",
                        onSelect = function()
                            local ped = PlayerPedId()
                            local dict = "missmic4"
                            local clip = "michael_tux_fidget"

                            RequestAnimDict(dict)
                            while not HasAnimDictLoaded(dict) do
                                Wait(10)
                            end

                            TaskPlayAnim(ped, dict, clip, 8.0, -8.0, 1500, 48, 0, false, false, false)
                            Wait(3500)
                            TriggerServerEvent("rs_outfitbag:wearOutfit", outfit.id)
                        end
                    },
                    {
                        title = Language.rename,
                        icon = "pen",
                        onSelect = function()
                            local newName = lib.inputDialog(Language.renameoutfit, {
                                { type = "input", label = Language.renameoutfitname, default = outfit.name }
                            })
                            if newName and newName[1] then
                                TriggerServerEvent("rs_outfitbag:renameOutfit", outfit.id, newName[1])
                            end
                        end
                    },
                    {
                        title = Language.delete,
                        icon = "trash",
                        onSelect = function()
                            TriggerServerEvent("rs_outfitbag:deleteOutfit", outfit.id)
                        end
                    }
                }

                lib.registerContext({
                    id = "outfit:" .. outfit.id,
                    title = outfit.name,
                    options = options
                })
            end

            lib.registerContext({
                id = "outfits_main",
                title = Language.myoutfit,
                options = elements
            })

            lib.showContext("outfits_main")
        end)
    elseif framework == "qb" then
        QBCore.Functions.TriggerCallback("rs_outfitbag:getOutfits", function(outfits)
            if not outfits or #outfits == 0 then
                Notify(Language.title, Language.nooutfits, 'error')
                return
            end

            local elements = {}

            for _, outfit in pairs(outfits) do
                table.insert(elements, {
                    title = outfit.name,
                    description = Language.moreoptions,
                    icon = "shirt",
                    menu = "outfit:" .. outfit.id
                })

                local options = {
                    {
                        title = Language.dressup,
                        icon = "tshirt",
                        onSelect = function()
                            local ped = PlayerPedId()
                            local dict = "missmic4"
                            local clip = "michael_tux_fidget"

                            RequestAnimDict(dict)
                            while not HasAnimDictLoaded(dict) do
                                Wait(10)
                            end

                            TaskPlayAnim(ped, dict, clip, 8.0, -8.0, 1500, 48, 0, false, false, false)
                            Wait(3500)
                            TriggerServerEvent("rs_outfitbag:wearOutfit", outfit.id)
                        end
                    },
                    {
                        title = Language.rename,
                        icon = "pen",
                        onSelect = function()
                            local newName = lib.inputDialog(Language.renameoutfit, {
                                { type = "input", label = Language.renameoutfitname, default = outfit.name }
                            })
                            if newName and newName[1] then
                                TriggerServerEvent("rs_outfitbag:renameOutfit", outfit.id, newName[1])
                            end
                        end
                    },
                    {
                        title = Language.delete,
                        icon = "trash",
                        onSelect = function()
                            TriggerServerEvent("rs_outfitbag:deleteOutfit", outfit.id)
                        end
                    }
                }

                lib.registerContext({
                    id = "outfit:" .. outfit.id,
                    title = outfit.name,
                    options = options
                })
            end

            lib.registerContext({
                id = "outfits_main",
                title = Language.myoutfit,
                options = elements
            })

            lib.showContext("outfits_main")
        end)
    elseif framework == "custom" then
        -- Add your custom framework logic here
    end
end)


if Config.Command.enabled then
    RegisterCommand(Config.Command.command, function()
        DebugPrint('Bag has been opened')
        TriggerEvent('rs_outfitbag:place')
    end)
end

exports('place', function()
 TriggerEvent('rs_outfitbag:place')
end)

RegisterNetEvent('rs_outfitbag:placed')
AddEventHandler('rs_outfitbag:placed',function ()
    DebugPrint('Bag has been placed')
    TriggerServerEvent('rs_outfitbag:placedBag')
end)

RegisterNetEvent('rs_outfitbag:pickedup')
AddEventHandler('rs_outfitbag:pickedup', function()
    DebugPrint('Progress bar for picking up bag has started')



        local ped = PlayerPedId()

        local dict = "random@domestic"
        local clip = "pickup_low"
        local model = Config.Prop 


        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(10)
        end


        RequestModel(model)        
        while not HasModelLoaded(model) do
            Wait(10)
        end


        local boneIndex = GetPedBoneIndex(ped, 57005)


        local x, y, z = table.unpack(GetEntityCoords(ped))
        local prop = CreateObject(GetHashKey(model), x, y, z + 0.2, true, true, false)
        SetEntityCollision(prop, false, false)
        SetEntityVisible(prop, true, false)


        AttachEntityToEntity(prop, ped, boneIndex, 0.12, 0.02, 0.02, 80.0, 180.0, 170.0, true, true, false, true, 1, true)        

    
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, 1500, 48, 0, false, false, false)

        Wait(1500)

        DeleteObject(prop)
        ClearPedTasks(ped)

    DebugPrint('Progress bar completed')
    TriggerServerEvent('rs_outfitbag:pickedupBag')
    DebugPrint('Bag has been added to inventory')

    local playerCoords = GetEntityCoords(PlayerPedId())
    local model = GetHashKey(Config.Prop)
    local closestBag = GetClosestObjectOfType(playerCoords, 2.0, model, false, false, false)

    if closestBag and DoesEntityExist(closestBag) then
        DebugPrint('Found outfitbag prop. Deleting...')
        NetworkRequestControlOfEntity(closestBag)
        Wait(100)

        if NetworkHasControlOfEntity(closestBag) then
            DeleteEntity(closestBag)
            DebugPrint('Outfitbag entity deleted')
        else
            DebugPrint('Failed to gain control of outfitbag entity')
        end
    else
        DebugPrint('No valid outfitbag entity found near player')
    end


end)

RegisterNetEvent('rs_outfitbag:place')
AddEventHandler('rs_outfitbag:place',function ()
    RequestModel(Config.Prop)
    while not HasModelLoaded(Config.Prop) do Citizen.Wait(10) DebugPrint('Loading bag model...') end
    local ped = PlayerPedId()

    local count
    if Config.Inventory == 'ox' then
	 count = lib.callback.await('ox_inventory:getItemCount', false, Config.Item.item, {})
     if count == nil then
        DebugPrint('Player does not have the required item: '.. Config.Item.item)
            if Config.Notify == 'esx' then
                Notify(Language.noitem)
            else
                Notify(Language.title, Language.noitem, 'error')
            end
        return
     end
    elseif Config.Inventory == 'qs' then
	 count = exports['qs-inventory']:Search(Config.Item.item)
          if count == nil then
        DebugPrint('Player does not have the required item: '.. Config.Item.item)
            if Config.Notify == 'esx' then
                Notify(Language.noitem)
            else
                Notify(Language.title, Language.noitem, 'error')
            end
        return
     end
    elseif Config.Inventory == 'codem' then
        count = lib.callback.await('codem_inventory:getItemCount', false, Config.Item.item, {})
             if count == nil then
        DebugPrint('Player does not have the required item: '.. Config.Item.item)
            if Config.Notify == 'esx' then
                Notify(Language.noitem)
            else
                Notify(Language.title, Language.noitem, 'error')
            end
        return
    elseif Config.Inventory == 'qb' then
        local playerData = QBCore.Functions.GetPlayerData()
        local count = 0

        for _, item in pairs(playerData.items) do
            if item.name == Config.Item.item then
                count = item.amount
                break
            end
        end

        if count <= 0 then
            DebugPrint('Player does not have the required item: ' .. Config.Item.item)
            if Config.Notify == 'esx' then
                Notify(Language.noitem)
            else
                Notify(Language.title, Language.noitem, 'error')
            end
            return
        end
    elseif Config.Inventory == 'custom' then
                 -- Custom inventory logic here
     end
    else
        DebugPrint('Invalid inventory type set in Config.Inventory')
        return
    end

    local x, y, z = table.unpack(GetEntityCoords(ped))
    if count >= 1 then
        DebugPrint('Player has '..count..' outfit bags')

        local ped = PlayerPedId()

        local dict = "random@domestic"
        local clip = "pickup_low"
        local model = Config.Prop 


        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(10)
        end


        RequestModel(model)        
        while not HasModelLoaded(model) do
            Wait(10)
        end


        local boneIndex = GetPedBoneIndex(ped, 57005) 


        local x, y, z = table.unpack(GetEntityCoords(ped))
        local prop = CreateObject(GetHashKey(model), x, y, z + 0.2, true, true, false)
        SetEntityCollision(prop, false, false)
        SetEntityVisible(prop, true, false)


        AttachEntityToEntity(prop, ped, boneIndex, 0.12, 0.02, 0.02, 80.0, 180.0, 170.0, true, true, false, true, 1, true)        

       
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, 1500, 48, 0, false, false, false)


        Wait(1500)


        DeleteObject(prop)
        ClearPedTasks(ped)


        TriggerEvent('rs_outfitbag:placed')
        local outfitbag = CreateObject(Config.Prop, x, y, z-1, true, false, false)
        SetEntityHeading(outfitbag, GetEntityHeading(ped))
        PlaceObjectOnGroundProperly(outfitbag)
        table.insert(outfitbags, outfitbag)
        if Config.Notify == 'esx' then
           Notify(Language.placeditem)
        else
           Notify(Language.title, Language.placeditem, 'success')
        end
    else
        DebugPrint('Player doesn\'t have the required item: '.. Config.Item.item)
    end
end)

function stopScript()
    DebugPrint('Ukončuji všechny události a entitky.')

    for _, bag in ipairs(outfitbags) do
        if DoesEntityExist(bag) then
            DeleteEntity(bag)
            DebugPrint('Bag entity has been deleted.')
        end
    end
    outfitbags = {}  

    DebugPrint('All events have been unregistered.')

    Citizen.CreateThread(function()
        DebugPrint('Stopping client script...')
        SetTimeout(1000, function()  
            ForceSocialClubUpdate()  
            DebugPrint('Client script has been stopped.')
        end)
    end)
    DebugPrint('Script has been stopped.')
end

AddEventHandler('onResourceStart', function(resourceName)
    local resourceName = 'rs_outfitbagv2'

    if resourceName == GetCurrentResourceName() then
        for k, bag in pairs(outfitbags) do
            DebugPrint('Trying to deleted outfitbag with hash key: '..bag)
            if DoesEntityExist(bag) then DeleteEntity(bag) DebugPrint('Deleted '..bag) end
        end
    elseif resourceName ~= GetCurrentResourceName() then
        stopScript()
    end
end)
