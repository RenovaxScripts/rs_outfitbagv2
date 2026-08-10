--------------------------
--------- Notify ---------
--------------------------

function Notify(title, desc, type)
    while Config.Notify == 'auto' do Wait(100) end

    if Config.Notify == 'esx' then
        while ESX == nil do Wait(100) end
        ESX.ShowNotification(desc or title)
    elseif Config.Notify == 'qb' then
        while QBCore == nil do Wait(100) end
        QBCore.Functions.Notify(title, type, 5000)
    elseif Config.Notify == 'ox' then
        lib.notify({
            title = title,
            description = desc,
            type = type,
            position = 'top-right',
            icon = 'shirt',
        })
    elseif Config.Notify == 'custom' then
        -- Add Your custom notify
        print("^3[WARNING]^0 Notify called but custom notify not defined!")
    end
end

---------------------------
-- Interaction Functions --
---------------------------






--------------------------
--------- Target ---------
--------------------------


function InteractionTarget()
    if Config.Target == 'ox_target' then
        local options = {
            {
                canInteract = function(_, distance, _)
                    if IsEntityDead(PlayerPedId()) then return false end
                    if distance >= Config.Distance then return false end
                    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                   return true
                end,
                event = 'rs_outfitbag:open',
                icon = 'fa-solid fa-shirt',
                label = Language.open,
                distance = Config.Distance + 0.1
            },
            {
            canInteract = function(_, distance, _)
                    if IsEntityDead(PlayerPedId()) then return false end
                    if distance >= Config.Distance then return false end
                    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                    return true
                end,
                event = 'rs_outfitbag:pickedup',
                icon = 'fa-solid fa-hand',
                label = Language.pickup,
                distance = Config.Distance + 0.1
            },
        }

        exports.ox_target:addModel(Config.Prop, options)
        print('Added bag model to ox_target options')
    elseif Config.Target == 'qtarget' then
         exports['qtarget']:AddTargetModel(Config.Prop, {
            options = {
                {
                    type = "client",
                    event = "rs_outfitbag:open",
                    icon = "fa-solid fa-shirt",
                    label = Language.open,
                    canInteract = function(entity, distance)
                        if IsEntityDead(PlayerPedId()) then return false end
                        if distance >= Config.Distance then return false end
                        if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                        return true
                    end,
                },
                {
                    type = "client",
                    event = "rs_outfitbag:pickedup",
                    icon = "fa-solid fa-hand",
                    label = Language.pickup,
                    canInteract = function(entity, distance)
                        if IsEntityDead(PlayerPedId()) then return false end
                        if distance >= Config.Distance then return false end
                        if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                        return true
                    end,
                },
            },
            distance = Config.Distance + 0.1
        })

        print('Added bag model to qtarget options')

    elseif Config.Target == 'qb_target' then
        exports['qb-target']:AddTargetModel(Config.Prop, {
            options = {
                {
                    type = "client",
                    event = "rs_outfitbag:open",
                    icon = "fa-solid fa-shirt",
                    label = Language.open,
                    canInteract = function(entity, distance)
                        if IsEntityDead(PlayerPedId()) then return false end
                        if distance >= Config.Distance then return false end
                        if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                        return true
                    end
                },
                {
                    type = "client",
                    event = "rs_outfitbag:pickedup",
                    icon = "fa-solid fa-hand",
                    label = Language.pickup,
                    canInteract = function(entity, distance)
                        if IsEntityDead(PlayerPedId()) then return false end
                        if distance >= Config.Distance then return false end
                        if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                        return true
                    end
                },
            },
            distance = Config.Distance + 0.1
        })

        print('Added bag model to qb-target options')

    elseif Config.Target == 'custom' then
        -- Add Your custom target
        print("^3[WARNING]^0 Target called but custom target not defined!")
    end
end

---------------------------
--------- Text UI ---------
---------------------------

function InteractionTextui()
    local bag, zone, isNear = nil, nil, false
    local propHash = GetHashKey(Config.Prop)
    if Config.TextUI == 'ox_lib' then
        CreateThread(function()
            while not ESX do Wait(100) end

            
            while true do
                Wait(500)

                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)

                
                local nearbyBag = GetClosestObjectOfType(coords, 2.0, propHash, false, false, false)

                if nearbyBag ~= 0 then
                    local bagCoords = GetEntityCoords(nearbyBag)
                    local dist = #(coords - bagCoords)

                    if dist <= Config.Distance then
                        if not isNear then
                            isNear = true
                            bag = nearbyBag

                            lib.showTextUI('[E] - Open outfit bag\n[Q] - Pick up outfit bag')
                            CreateThread(function()
                                while isNear do
                                    if IsControlJustReleased(0, 38) then
                                        TriggerEvent('rs_outfitbag:open')
                                    elseif IsControlJustReleased(0, 44) then
                                        TriggerEvent('rs_outfitbag:pickedup')
                                    end
                                    Wait(0)
                                end
                            end)
                        end
                    else
                        if isNear then
                            isNear = false
                            lib.hideTextUI()
                        end
                    end
                else
                    if isNear then
                        isNear = false
                        lib.hideTextUI()
                    end
                end
            end
        end)

        print('Added bag model to ox_lib textui options')
    elseif Config.TextUI == 'esx_textui' then
        
    elseif Config.TextUI == 'custom' then
        print("^3[WARNING]^0 Target called but custom target not defined!")
    end
end



--------------------------
--------- Custom ---------
--------------------------


function InteractionCustom()
    -- Add Your custom interaction
    print("^3[WARNING]^0  Function called but custom interaction not defined!") -- you can remove this line if you have custom interaction
end