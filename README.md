# Renovax Scripts | Multijob

Multijob management system for Qbox, ESX Legacy & QBCore allowing players to switch between saved jobs, toggle duty status, view salaries, and search positions via NUI interface.

## — FEATURES LIST —

### Core Features
  - **Multijob Management & Real-Time Switching**
    Allows players to save and switch between multiple jobs seamlessly without server latency with automatic slot tracking and live search bar.
  - **Advanced Duty System**
    Full support for On-Duty / Off-Duty toggling for Qbox & QBCore (`SetJobDuty` native) as well as ESX Legacy (`off_` job prefix system) with smart job normalization.
  - **In-Game Admin Management**
    Use `/addmultijob`, `/removemultijob`, and `/listmultijobs` commands with Ace, Qbox group, ESX group, and QBCore permission integration.

### Customization & Compatibility
  - **Framework & Database Compatibility**
    Supports Qbox, ESX Legacy and QBCore out of the box with native `oxmysql` and `mysql-async` auto-table creation.
  - **Notification Systems**
    Built-in integration for `ox_lib`, `qbx`, `esx`, `qb`, and custom notifications.
  - **Multi-Language Localization**
    Includes Czech (`cz`) and English (`en`) locales out of the box with simple key-based translations.

### Additional Features
  - **Secure Server Config**
    Sensitive data like Webhook URLs and Admin Groups are placed in `server_config.lua` to prevent client-side data leaks.


## — GET IT FOR FREE —
Download now on GitHub:
[rs_multijob](https://github.com/RenovaxScripts/rs_multijob)

More updates coming soon!

## — CONFIGURATION —

Hlavní konfigurace skriptu umožňuje nastavit framework, klávesové zkratky, limity jobů, ikony, oprávnění a upozornění. Všechny možnosti najdeš v souboru `config.lua`:

```lua
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
```

## Recommended FiveM Hosting — RocketNode

Looking for reliable hosting for your FiveM server?

We personally recommend **RocketNode** as our preferred hosting provider for running our scripts and resources.

RocketNode provides FiveM server hosting suitable for communities looking for a reliable and high-performance environment to run their server and our resources.

### Get 25% OFF

**Use our affiliate link:**

https://rocketnode.us/RENOVAX

and apply the following discount code at checkout:

**`RENOVAX`**

to receive **25% OFF** your RocketNode hosting.

> **RocketNode is our recommended hosting provider for using our scripts and resources.**

— LINKS —
[TEBEX](https://renovax-scripts.xyz/)
[YOUTUBE](https://youtu.be/IA_mrl0Ywvc)
[DOCS](https://renovax-scripts.gitbook.io/renovax-scripts-docs)
[DISCORD](https://discord.gg/SHjXNe4k7h)
