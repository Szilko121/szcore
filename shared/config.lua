SzCoreConfig = {
    Debug = false,
    Version = '1.4.0-rc1',
    IdentifierPriority = { 'license2', 'license' },
    MaxCharacters = 4,
    AutoSaveInterval = 300000,
    PositionSaveDistance = 10.0,
    CallbackTimeout = 15000,
    CallbackRate = { WindowMs = 1000, MaxRequests = 35 },
    SecureEventRate = { WindowMs = 1000, MaxRequests = 20 },
    Queue = { Enabled = true, RefreshMs = 1500, ReservedSlots = 0 },
    Paycheck = { Enabled = true, IntervalMs = 900000, Account = 'bank' },
    Locale = 'hu',
    StartingMoney = { cash = 2500, bank = 15000, crypto = 0, dirty = 0 },
    DefaultJob = { name = 'unemployed', grade = 0, duty = false },
    DefaultGang = { name = 'none', grade = 0 },
    DefaultMetadata = {
        hunger = 100, thirst = 100, stress = 0, dead = false, armor = 0,
        ishandcuffed = false, jail = 0, phone = nil, licenses = {},
        medical = { bleeding = 0, pain = 0, lastStand = false, dead = false, injuries = {} }
    },
    DefaultPosition = { x = -1037.72, y = -2737.66, z = 20.17, w = 329.0 },
    Money = {
        AllowNegative = { cash = false, bank = false, crypto = false, dirty = false },
        MinimumBank = 0,
        AuditLedger = true
    },
    Audit = { Enabled = true, RetentionDays = 30 },
    Inventory = { DefaultSlots = 40, DefaultWeight = 120000 },
    Vehicle = { DefaultGarage = 'legion', PersistLastPosition = true },
}
