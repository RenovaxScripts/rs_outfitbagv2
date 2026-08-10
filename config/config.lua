Config = {}

Config.Debug = true -- If true, you will get an additional F8 prints for what's going on

Config.Framework = 'qb' -- esx = ESX, qb = QBCore, custom = Csutom Framework - change in cl_edit.lua
-- or if you want you can set it to 'auto' and it will detect the framework automatically

Config.Notify = 'ox' -- esx = ESX, qb = QBCore, ox = OxLib, custom = Custom Notify - change in cl_edit.lua
-- or if you want you can set it to 'auto' and it will detect the notify automatically


Config.Inventory = 'ox' -- ox = Ox inventory, qs = Qs inventory, codem = CodeM inventory, qb = QB Inventory, custom = Custom Inventory - change in sv_edit.lua
-- or you can set it to 'auto' and it will detect the inventory automatically

Config.Menu = 'ox' -- ox = Ox lib menu, qb = qb menu, custom = Custom Menu - change in cl_edit.lua

Config.InteractionType = 'target' -- textui = Ox Lib Text ui - you can change in cl_edit.lua, target = Target system qb-target/qtarget/ox_target,
-- custom = Custom Interaction - change in cl_edit.lua

Config.Target = 'auto' -- qb-target, qtarget, ox_target, custom - change in cl_edit.lua
-- or you can set it to 'auto' and it will detect the target automatically

Config.TextUI = 'auto' -- ox_lib = Ox lib text ui, esx_textui = ESX Text ui,custom - change in cl_edit.lua
-- or you can set it to 'auto' and it will detect the text ui automatically


Config.MaxOutfits = 5

Config.Item = {
    enabled = true,
    item = 'outfit_bag'
}

Config.Command = {
    enabled = true,
    command = 'outfitbag'
}

Config.Distance = 4

Config.Prop = 'prop_cs_heist_bag_02'
