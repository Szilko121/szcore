--- @class Config
Config = {}

-- Általános beállítások (General Settings)
Config.Debug = false
Config.Locale = 'hu' -- 'hu' vagy 'en'

-- SzCore integrációs konfiguráció
Config.ResourceName = 'szcore'
Config.CheckInterval = 5000 -- ms

-- Egyedi modul beállítások
Config.Settings = {
    enabled = true,
    allowNotifications = true,
    defaultTimeout = 10000,
}
