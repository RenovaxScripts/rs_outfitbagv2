if Config.Inventory == 'auto' then
    CreateThread(function()
        if GetResourceState('nord_inventory') == 'started' then
            Config.Inventory = 'nord'
        elseif GetResourceState('ox_inventory') == 'started' then
            Config.Inventory = 'ox'
        elseif GetResourceState('qs-inventory') == 'started' then
            Config.Inventory = 'qs'
        elseif GetResourceState('codem-inventory') == 'started' then
            Config.Inventory = 'codem'
        elseif GetResourceState('qb-inventory') == 'started' then
            Config.Inventory = 'qb'
        else
            Config.Inventory = 'custom'
        end
    end)
end

