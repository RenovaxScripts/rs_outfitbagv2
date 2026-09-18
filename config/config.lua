Config = {}

-- ====================================================================
-- GENERAL & FRAMEWORK SETTINGS
-- ====================================================================

--- @field Locale string Language code ('cs' | 'en')
Config.Locale = 'cs'

--- @field Framework string Game framework ('esx' | 'qb')
Config.Framework = 'esx'

--- @field Inventory string Inventory resource name
Config.Inventory = GetResourceState('nord_inventory') == 'started' and 'nord_inventory' or 'ox_inventory'

--- @field Target string Targeting resource name
Config.Target = 'ox_target'

--- @field Debug boolean Enable debug mode (extra prints, NPC scanning, zone visualization)
Config.Debug = true

-- ====================================================================
-- HANDHELD SCANNER SETTINGS
-- ====================================================================

--- @field HandScannerItem string Inventory item name required for handheld scanning
Config.HandScannerItem = 'metal_scanner'

--- @field HandScannerProp string Primary hand scanner prop model
Config.HandScannerProp = 'hand_metal_detector'

--- @field HandScannerFallbackProp string Fallback prop if primary model fails to load
Config.HandScannerFallbackProp = 'w_am_digiscanner'

--- @field ScanDuration number Duration of the scan progress bar in milliseconds
Config.ScanDuration = 5000

--- @field ScanDistance number Maximum interaction distance to scan a player
Config.ScanDistance = 2.0

--- @field ScanServerCooldown number Server-side cooldown between handheld scans in ms
Config.ScanServerCooldown = 1500

--- @field ShowDetectedItems boolean Whether to show names of detected items to the officer
Config.ShowDetectedItems = false

--- @field HandScannerBeep boolean Play beep sound on hand scanner detection
Config.HandScannerBeep = true

--- Hand scanner animation played on the scanning officer
Config.HandScannerAnimation = {
    dict = 'mini@repair',
    clip = 'fixing_a_ped',
    flag = 49
}

--- Hand scanner prop attachment settings (bone, position, rotation)
Config.HandScannerAttachment = {
    bone = 57005,
    position = vec3(0.12, 0.02, -0.02),
    rotation = vec3(-80.0, 0.0, -15.0)
}

--- Optional animation forced on the player being scanned
Config.TargetScannerAnimation = {
    enabled = false,
    dict = 'random@mugging0',
    clip = 'handsup_standing',
    flag = 49
}

-- ====================================================================
-- WALKTHROUGH DETECTOR SETTINGS
-- ====================================================================

--- @field WalkthroughDetectorModel string Prop model used for walkthrough detectors
Config.WalkthroughDetectorModel = 'ch_prop_ch_metal_detector_01a'

--- Walkthrough detector defaults
Config.DefaultRadius = 0.6
Config.DefaultCooldown = 3000
Config.MaximumRadius = 25.0
Config.MinimumCooldown = 500
Config.DuplicateDistance = 0.75

--- Box zone dimensions for walkthrough detectors
Config.BoxZoneDepth = 1.25
Config.BoxZoneHeight = 3.0
Config.DetectorPropZOffset = -1.0

-- ====================================================================
-- DETECTION RULES & ITEM LISTS
-- ====================================================================

--- Automatically detect all weapons (items starting with 'weapon_')
Config.DetectAllWeapons = true

--- Weapons exempt from metal detection (e.g. non-metal, plastic, taser)
Config.IgnoredWeapons = {
    ['weapon_stungun'] = true,
    ['WEAPON_ACIDPACKAGE'] = true,
    ['WEAPON_STONE_HATCHET'] = true,
    ['WEAPON_CANDYCANE'] = true,
    ['WEAPON_POOLCUE'] = true,
}

--- Items that trigger the metal detector
Config.MetalItems = {
    -- Vests & Ammo
    ['vest_light'] = true,
    ['vest_medium'] = true,
    ['vest_heavy'] = true,
    ['box-99'] = true,
    ['box-50'] = true,
    ['box-rifle'] = true,
    ['box-rifle2'] = true,
    ['box-shotgun'] = true,

    -- Raw Materials & Scrap
    ['scrapmetal'] = true,
    ['metalscrap'] = true,
    ['aluminum'] = true,
    ['copper'] = true,
    ['iron'] = true,
    ['gold'] = true,
    ['gold_bar'] = true,

    -- Tools & Equipment
    ['blowpipe'] = true,
    ['carokit'] = true,
    ['carotool'] = true,
    ['fixkit'] = true,
    ['fixtool'] = true,
    ['defibrilator'] = true,
    ['screwdriver'] = true,
    ['trowel'] = true,
    ['nxlopata'] = true,
    ['zahradnickenuzky'] = true,
    ['lockpick'] = true,
    ['crowbar'] = true,
    ['angle_grinder'] = true,
    ['large_drill'] = true,
    ['small_drill'] = true,
    ['plasma_cutter'] = true,

    -- Road Barriers
    ['consign'] = true,
    ['barrier'] = true,
    ['roadcone_light'] = true,

    -- Electronics
    ['radio'] = true,
    ['garbage_tablet'] = true,
    ['boosting_tablet'] = true,
    ['laptop'] = true,
    ['notebook'] = true,
    ['microwave'] = true,
    ['tv'] = true,
    ['monitor'] = true,
    ['printer'] = true,
    ['flat_tv'] = true,
    ['old_tv'] = true,
    ['dj_deck'] = true,
    ['console'] = true,
    ['powerbank'] = true,
    ['phone'] = true,
    ['phone_gold'] = true,
    ['boombox'] = true,
    ['rob_gps'] = true,
    ['rob_dron'] = true,
    ['rob_pad'] = true,
    ['rob_rozjebanytelefon'] = true,

    -- Valuables & Heist Items
    ['rob_jewels'] = true,
    ['rob_empty_casing'] = true,
    ['rob_empty_box'] = true,
    ['thermite'] = true,
    ['bracelet'] = true,
    ['coin'] = true,
    ['binoculars'] = true,
    ['ls_auto_parts'] = true,
    ['ls_torch'] = true,
    ['ls_lug_wrench'] = true,
    ['ls_vehicle_finder'] = true,
    ['bomb_c4'] = true,
    ['explosives'] = true,
    ['gazbottle'] = true,

    -- Weapon Components
    ['craft_zasobnik'] = true,
    ['craft_hlaven'] = true,
    ['craft_spust'] = true,
    ['craft_gunbody'] = true,
    ['craft_pruzina'] = true,

    -- Misc Metal Gear
    ['ballistic_shield'] = true,
    ['riot_shield'] = true,
    ['deployable_light'] = true,
    ['ls_oxygen_tank'] = true,
}

--- Items whitelisted from detection (always pass through undetected)
Config.WhitelistedItems = {
    -- ['phone'] = true,
    -- ['radio'] = true,
    -- ['keys'] = true,
    -- ['badge'] = true,
    -- ['handcuffs'] = true,
}

-- ====================================================================
-- JOB RESTRICTIONS & NOTIFICATIONS
-- ====================================================================

--- Jobs that receive detection notifications
Config.NotifyJobs = {
    police = true,
    sheriff = true
}

--- Jobs ignored by walkthrough detectors (pass through without triggering scan)
Config.IgnoredJobs = {
    police = true,
}

--- Jobs blacklisted from walkthrough detection
Config.BlacklistedJobs = {
    -- ambulance = true,
    -- mechanic = true,
}

-- ====================================================================
-- ALARM, AUDIO & VISUAL EFFECTS
-- ====================================================================

--- Alarm mode: 'beep_only' | 'beep_and_notify' | 'notify_only'
Config.AlarmMode = 'beep_and_notify'

--- Who receives the detection notification alert
Config.NotificationAudience = {
    triggeringPlayer = false,
    nearbyPlayers = true,
    notifyJobs = false,
    admins = false
}

--- Maximum radius from detector where nearby players hear/receive alert
Config.NotificationRadius = 15.0

--- Sound settings for walkthrough detector alarm
Config.BeepSound = {
    enabled = true,
    name = 'Beep_Red',
    set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS',
    distance = 10.0,
    volume = 1.0
}

--- Visual 3D LED flash effect on walkthrough detectors during alarm
Config.DetectorFlash = {
    enabled = true,
    enableRedLight = true,
    flashes = 4,
    interval = 150
}

-- ====================================================================
-- POLICE DISPATCH INTEGRATION
-- ====================================================================

--- Supported systems: 'cd_dispatch' | 'ps-dispatch' | 'ps-dispatch-client' | 'qs-dispatch' | 'custom' | 'none'
Config.Dispatch = {
    enabled = true,
    system = 'cd_dispatch',
    jobs = { 'police', 'sheriff' },
}

-- ====================================================================
-- ADMIN PERMISSIONS (FALLBACK)
-- ====================================================================

--- Admin groups allowed to open /metalscanner creator
--- Note: ServerConfig.AdminGroups in server_config.lua takes precedence
Config.AdminGroups = {
    admin = true,
    superadmin = true,
    owner = true
}
