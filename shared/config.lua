Config = Config or {}

Config.BackWeapon = {
    command = 'hopebackweapon',
    aliases = { 'armedos' },
    stateKey = 'hopeBackWeapon',
    inventoryRefreshDelay = 125,
    visibilityInterval = 250,
    scopeScanInterval = 5000,
    modelLoadTimeout = 2500,
    modelRetryDelay = 10000,
    attachments = {
        default = {
            bone = 24818,
            position = { 0.075, -0.155, 0.015 },
            rotation = { 0.0, 165.0, 0.0 }
        },
        compact = {
            bone = 51826,
            position = { 0.09, -0.02, 0.02 },
            rotation = { 90.0, 0.0, 0.0 }
        },
        pistol = {
            bone = 51826,
            position = { 0.11, -0.02, -0.02 },
            rotation = { 90.0, 0.0, 0.0 }
        },
        melee = {
            bone = 24818,
            position = { 0.13, -0.15, 0.05 },
            rotation = { 0.0, 90.0, 0.0 }
        },
        throwable = {
            bone = 24818,
            position = { 0.16, -0.13, 0.12 },
            rotation = { 0.0, 90.0, 0.0 }
        }
    },
    weaponOverrides = {}
}
