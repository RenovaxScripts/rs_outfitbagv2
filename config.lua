Config = {}

Config.Framework = 'auto' -- 'auto', 'qbox', 'esx', 'qbcore'
Config.AutoFrameworkPriority = { 'qbox', 'esx', 'qbcore' }
Config.Locale = 'en'

Config.Command = 'multijob'
Config.Keybind = 'F6'
Config.MaxJobs = 5
Config.DefaultJob = 'unemployed'
Config.DefaultGrade = 0
Config.SwitchCooldown = 10

Config.ShowSalary = true
Config.SalaryFormat = '$%s'

Config.EnableDuty = true
Config.OffDutyPrefix = 'off_'

Config.JobIcons = {
    ['police']     = 'fa-solid fa-shield-halved',
    ['sheriff']    = 'fa-solid fa-star',
    ['ambulance']  = 'fa-solid fa-user-nurse',
    ['mechanic']   = 'fa-solid fa-wrench',
    ['taxi']       = 'fa-solid fa-taxi',
    ['cardealer']  = 'fa-solid fa-car',
    ['realestate'] = 'fa-solid fa-house',
    ['unemployed'] = 'fa-solid fa-user-slash',
    ['reporter']   = 'fa-solid fa-newspaper',
    ['garbage']    = 'fa-solid fa-trash-can',
    ['lawyer']     = 'fa-solid fa-scale-balanced',
    ['mafia']      = 'fa-solid fa-user-ninja'
}

Config.WhitelistJobs = {}
Config.BlacklistJobs = {}
Config.AutoSaveJobs = true
Config.AutoSaveInterval = 30
Config.AllowPlayerRemove = true

Config.Notification = 'ox_lib' -- 'ox_lib', 'qbx', 'esx', 'qb', 'custom'
Config.NotificationDuration = 5000
Config.CustomNotify = function(message, notifyType)
    print(('[rs_multijob] [%s] %s'):format(notifyType or 'info', message))
end

Config.Database = 'oxmysql'
Config.DatabaseTable = 'rs_multijob_jobs'
Config.AutoCreateTable = true

Config.Admin = {
    Enabled = true,
    Commands = {
        Add = 'addmultijob',
        Remove = 'removemultijob',
        List = 'listmultijobs'
    },
    Permission = {
        UseAce = true,
        Ace = 'rs_multijob.admin',
        UseQboxGroups = true,
        QboxGroups = { 'admin', 'god' },
        UseESXGroups = true,
        ESXGroups = {
            admin = true,
            superadmin = true
        },
        UseQBCorePermissions = true,
        QBCorePermissions = { 'admin', 'god' }
    }
}
