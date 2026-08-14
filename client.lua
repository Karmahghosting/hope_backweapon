Config = Config or {}

local cfg = (Config and Config.BackWeapon) or {}
local stateKey = cfg.stateKey or 'hopeBackWeapon'
local tracked = {}
local inventoryRefreshGeneration = 0

local groupProfiles = {
    [joaat('GROUP_PISTOL')] = 'pistol',
    [joaat('GROUP_STUNGUN')] = 'pistol',
    [joaat('GROUP_SMG')] = 'compact',
    [joaat('GROUP_MELEE')] = 'melee',
    [joaat('GROUP_THROWN')] = 'throwable',
    [joaat('GROUP_PETROLCAN')] = 'throwable',
    [joaat('GROUP_FIREEXTINGUISHER')] = 'compact'
}

local function notify(message, notificationType)
    lib.notify({
        title = 'Arme dans le dos',
        description = message,
        type = notificationType or 'inform'
    })
end

local function normalizePayload(value)
    if type(value) ~= 'table' then return nil end
    if type(value.name) ~= 'string' then return nil end
    if type(value.model) ~= 'string' and type(value.model) ~= 'number' then return nil end

    return {
        name = value.name,
        model = value.model,
        slot = tonumber(value.slot)
    }
end

local function modelHash(model)
    if type(model) == 'number' then return model end
    if type(model) == 'string' then return joaat(model) end
end

local function clearBackObject(record)
    local entity = record and record.entity
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end

    if record then
        record.entity = nil
        record.ped = nil
        record.hash = nil
    end
end

local function setTrackedPayload(serverId, value)
    serverId = tonumber(serverId)
    if not serverId then return end

    local payload = normalizePayload(value)
    local record = tracked[serverId]

    if not payload then
        if record then clearBackObject(record) end
        tracked[serverId] = nil
        return
    end

    local visualSignature = ('%s|%s'):format(payload.name, tostring(payload.model))
    if not record then
        record = {
            generation = 0,
            visualSignature = visualSignature,
            payload = payload
        }
        tracked[serverId] = record
        return
    end

    record.payload = payload
    record.missingSince = nil

    if record.visualSignature ~= visualSignature then
        record.generation = record.generation + 1
        record.visualSignature = visualSignature
        record.failedUntil = nil
        clearBackObject(record)
    end
end

local function profileFor(payload, hash)
    local attachments = type(cfg.attachments) == 'table' and cfg.attachments or {}
    local overrides = type(cfg.weaponOverrides) == 'table' and cfg.weaponOverrides or {}
    local override = overrides[payload.name] or overrides[payload.name:upper()]
    if type(override) == 'table' then return override end

    local profileName = groupProfiles[GetWeapontypeGroup(hash)] or 'default'
    return attachments[profileName] or attachments.default or {
        bone = 24818,
        position = { 0.075, -0.155, 0.015 },
        rotation = { 0.0, 165.0, 0.0 }
    }
end

local function attachmentValues(profile)
    local position = type(profile.position) == 'table' and profile.position or {}
    local rotation = type(profile.rotation) == 'table' and profile.rotation or {}

    return tonumber(profile.bone) or 24818,
        tonumber(position[1]) or 0.075,
        tonumber(position[2]) or -0.155,
        tonumber(position[3]) or 0.015,
        tonumber(rotation[1]) or 0.0,
        tonumber(rotation[2]) or 165.0,
        tonumber(rotation[3]) or 0.0
end

local function attachObject(entity, ped, payload, hash)
    local profile = profileFor(payload, hash)
    local bone, x, y, z, pitch, roll, yaw = attachmentValues(profile)

    AttachEntityToEntity(
        entity,
        ped,
        GetPedBoneIndex(ped, bone),
        x, y, z,
        pitch, roll, yaw,
        false, false, false, false, 2, true
    )
end

local function requestBackObject(serverId, record, ped, hash)
    local now = GetGameTimer()
    if record.loadingGeneration == record.generation
        or (record.failedUntil and record.failedUntil > now)
    then
        return
    end

    local generation = record.generation
    record.loadingGeneration = generation
    local payload = record.payload

    CreateThread(function()
        RequestWeaponAsset(hash, 31, 0)

        local timeoutAt = GetGameTimer() + math.max(500, tonumber(cfg.modelLoadTimeout) or 2500)
        while not HasWeaponAssetLoaded(hash) and GetGameTimer() < timeoutAt do
            Wait(25)
        end

        local active = tracked[serverId]
        if active ~= record or active.generation ~= generation or not DoesEntityExist(ped) then
            RemoveWeaponAsset(hash)
            if active == record and active.loadingGeneration == generation then
                active.loadingGeneration = nil
            end
            return
        end

        if not HasWeaponAssetLoaded(hash) then
            if active.loadingGeneration == generation then active.loadingGeneration = nil end
            active.failedUntil = GetGameTimer() + math.max(1000, tonumber(cfg.modelRetryDelay) or 10000)
            RemoveWeaponAsset(hash)
            return
        end

        local coords = GetEntityCoords(ped)
        local entity = CreateWeaponObject(hash, 0, coords.x, coords.y, coords.z, true, 1.0, 0)
        RemoveWeaponAsset(hash)
        if active.loadingGeneration == generation then active.loadingGeneration = nil end

        if not entity or entity == 0 or not DoesEntityExist(entity) then
            active.failedUntil = GetGameTimer() + math.max(1000, tonumber(cfg.modelRetryDelay) or 10000)
            return
        end

        if tracked[serverId] ~= active or active.generation ~= generation or not DoesEntityExist(ped) then
            DeleteEntity(entity)
            return
        end

        SetEntityAsMissionEntity(entity, true, true)
        SetEntityCollision(entity, false, false)
        SetEntityCanBeDamaged(entity, false)
        SetEntityInvincible(entity, true)
        attachObject(entity, ped, payload, hash)

        active.entity = entity
        active.ped = ped
        active.hash = hash
        active.failedUntil = nil
    end)
end

local function updateTrackedPlayer(serverId, record, now)
    local playerIndex = GetPlayerFromServerId(serverId)
    if playerIndex == -1 or not NetworkIsPlayerActive(playerIndex) then
        clearBackObject(record)
        record.missingSince = record.missingSince or now
        if now - record.missingSince > 5000 then tracked[serverId] = nil end
        return
    end

    local ped = GetPlayerPed(playerIndex)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        clearBackObject(record)
        return
    end

    record.missingSince = nil
    if record.ped and record.ped ~= ped then clearBackObject(record) end

    local hash = modelHash(record.payload.model)
    if not hash then
        clearBackObject(record)
        return
    end

    local equipped = GetSelectedPedWeapon(ped) == hash
    if record.entity and DoesEntityExist(record.entity) then
        if record.ped ~= ped or record.hash ~= hash or not IsEntityAttachedToEntity(record.entity, ped) then
            clearBackObject(record)
        else
            SetEntityVisible(record.entity, not equipped, false)
            return
        end
    end

    if not equipped then requestBackObject(serverId, record, ped, hash) end
end

local function seedScopedPlayers()
    for _, playerIndex in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(playerIndex)
        local value = Player(playerIndex).state[stateKey]
        if value ~= nil then setTrackedPayload(serverId, value) end
    end
end

local function queueInventoryRefresh()
    inventoryRefreshGeneration = inventoryRefreshGeneration + 1
    local generation = inventoryRefreshGeneration

    SetTimeout(math.max(50, tonumber(cfg.inventoryRefreshDelay) or 125), function()
        if generation ~= inventoryRefreshGeneration then return end
        TriggerServerEvent('hope_backweapon:refresh')
    end)
end

local function selectBackSlot(slot)
    local result = lib.callback.await('hope_backweapon:select', false, slot)
    if type(result) ~= 'table' then
        return notify('Le serveur n a pas repondu.', 'error')
    end

    notify(result.message or (result.ok and 'Selection mise a jour.' or 'Selection refusee.'), result.ok and 'success' or 'error')
end

local function openBackWeaponMenu()
    local data = lib.callback.await('hope_backweapon:list', false)
    if type(data) ~= 'table' or data.ok ~= true then
        return notify('Impossible de lire ton inventaire.', 'error')
    end

    local options = {}
    local defaultWeapon = type(data.defaultWeapon) == 'table' and data.defaultWeapon or nil
    options[#options + 1] = {
        title = defaultWeapon and ('Slot 1  %s'):format(defaultWeapon.label) or 'Slot 1  aucune arme',
        description = data.defaultMode and 'Selection par defaut active' or 'Revenir a la selection par defaut',
        icon = 'rotate-left',
        iconColor = data.defaultMode and '#22c55e' or nil,
        onSelect = function() selectBackSlot(1) end
    }

    local otherWeapons = 0
    for i = 1, #(data.weapons or {}) do
        local weapon = data.weapons[i]
        if tonumber(weapon.slot) ~= 1 then
            otherWeapons = otherWeapons + 1
            local slot = tonumber(weapon.slot)
            options[#options + 1] = {
                title = ('Slot %s  %s'):format(tostring(slot), weapon.label or weapon.name),
                description = weapon.selected and 'Actuellement affichee' or 'Afficher cette arme dans le dos',
                icon = 'gun',
                iconColor = weapon.selected and '#22c55e' or nil,
                onSelect = function() selectBackSlot(slot) end
            }
        end
    end

    if otherWeapons == 0 then
        options[#options + 1] = {
            title = 'Aucune autre arme disponible',
            icon = 'circle-info',
            readOnly = true
        }
    end

    lib.registerContext({
        id = 'hope_backweapon_menu',
        title = 'Arme dans le dos',
        options = options
    })
    lib.showContext('hope_backweapon_menu')
end

AddStateBagChangeHandler(stateKey, nil, function(bagName, _, value)
    local serverId = tonumber(type(bagName) == 'string' and bagName:match('^player:(%d+)$') or nil)
    if serverId then setTrackedPayload(serverId, value) end
end)

RegisterNetEvent('ox_inventory:updateInventory', queueInventoryRefresh)
RegisterNetEvent('ox_inventory:currentWeapon', function()
    local serverId = GetPlayerServerId(PlayerId())
    local record = tracked[serverId]
    if record then updateTrackedPlayer(serverId, record, GetGameTimer()) end
end)

AddEventHandler('playerSpawned', queueInventoryRefresh)

RegisterCommand(cfg.command or 'hopebackweapon', openBackWeaponMenu, false)
for _, alias in ipairs(type(cfg.aliases) == 'table' and cfg.aliases or {}) do
    if type(alias) == 'string' and alias ~= '' then
        RegisterCommand(alias, openBackWeaponMenu, false)
    end
end

exports('openBackWeaponMenu', openBackWeaponMenu)

CreateThread(function()
    Wait(500)
    seedScopedPlayers()
    queueInventoryRefresh()

    local nextScopeScan = 0
    while true do
        local hasTrackedPlayers = next(tracked) ~= nil
        Wait(hasTrackedPlayers and math.max(100, tonumber(cfg.visibilityInterval) or 250) or 1000)

        local now = GetGameTimer()
        if now >= nextScopeScan then
            seedScopedPlayers()
            nextScopeScan = now + math.max(1000, tonumber(cfg.scopeScanInterval) or 5000)
        end

        for serverId, record in pairs(tracked) do
            updateTrackedPlayer(serverId, record, now)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, record in pairs(tracked) do clearBackObject(record) end
end)
