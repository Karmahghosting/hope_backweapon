Config = Config or {}

local ox_inventory = exports.ox_inventory
local DEFAULT_SLOT = 1
local selections = {}
local replicatedSignatures = {}
local refreshScheduled = {}
local lastSelectionAt = {}
local weaponDefinitions = {}

local function backConfig()
    return (Config and Config.BackWeapon) or {}
end

local function getWeaponDefinition(itemName)
    if type(itemName) ~= 'string' then return nil end
    local cached = weaponDefinitions[itemName]
    if cached ~= nil then
        return cached or nil
    end
    local definition = ox_inventory:Items(itemName)
    weaponDefinitions[itemName] = definition or false
    return definition
end

local function getWeaponSlot(source, slotId)
    slotId = tonumber(slotId)
    if not slotId or slotId < 1 or slotId % 1 ~= 0 then return nil end
    local item = ox_inventory:GetSlot(source, slotId)
    if type(item) ~= 'table' or type(item.name) ~= 'string' or (tonumber(item.count) or 0) < 1 then
        return nil
    end
    local definition = getWeaponDefinition(item.name)
    if not definition or definition.weapon ~= true then return nil end
    return item, definition
end

local function itemSerial(item)
    local metadata = item and item.metadata
    local serial = type(metadata) == 'table' and metadata.serial or nil
    if serial == nil or serial == '' then return nil end
    return tostring(serial)
end

local function selectionMatches(item, selection)
    if type(item) ~= 'table' or type(selection) ~= 'table' then return false end
    if item.name ~= selection.name then return false end
    local serial = itemSerial(item)
    if selection.serial then return serial == selection.serial end
    return true
end

local function findMovedSelection(source, selection)
    local items = ox_inventory:GetInventoryItems(source)
    if type(items) ~= 'table' then return nil end

    local singleMatch
    for _, item in pairs(items) do
        if selectionMatches(item, selection) then
            local definition = getWeaponDefinition(item.name)
            if definition and definition.weapon == true then
                if selection.serial then return item, definition end
                if singleMatch then return nil end
                singleMatch = { item = item, definition = definition }
            end
        end
    end

    if singleMatch then return singleMatch.item, singleMatch.definition end
end

local function resolveSelection(source)
    local selection = selections[source]
    if selection then
        local item, definition = getWeaponSlot(source, selection.slot)
        if item and selectionMatches(item, selection) then
            return item, definition, false
        end

        item, definition = findMovedSelection(source, selection)
        if item then
            selection.slot = tonumber(item.slot)
            return item, definition, false
        end

        selections[source] = nil
    end

    local item, definition = getWeaponSlot(source, DEFAULT_SLOT)
    return item, definition, true
end

local function buildPayload(item, definition)
    if not item or not definition then return false end
    return {
        name = item.name,
        model = definition.model or item.name,
        slot = tonumber(item.slot) or DEFAULT_SLOT
    }
end

local function payloadSignature(payload)
    if type(payload) ~= 'table' then return 'none' end
    return ('%s|%s|%s'):format(tostring(payload.name), tostring(payload.model), tostring(payload.slot))
end

local function syncPlayer(source)
    source = tonumber(source)
    if not source or not GetPlayerName(source) then return false end

    local item, definition, defaultMode = resolveSelection(source)
    local payload = buildPayload(item, definition)
    local signature = payloadSignature(payload)

    if replicatedSignatures[source] ~= signature then
        local player = Player(source)
        if player and player.state then
            player.state:set(backConfig().stateKey or 'hopeBackWeapon', payload, true)
            replicatedSignatures[source] = signature
        end
    end

    return payload, item, defaultMode
end

local function itemLabel(item, definition)
    local metadata = item and item.metadata
    return type(metadata) == 'table' and metadata.label
        or item and item.label
        or definition and definition.label
        or item and item.name
        or 'Arme'
end

local function listWeapons(source)
    local payload, selectedItem, defaultMode = syncPlayer(source)
    local items = ox_inventory:GetInventoryItems(source)
    local weapons = {}

    if type(items) == 'table' then
        for _, item in pairs(items) do
            local definition = type(item) == 'table' and getWeaponDefinition(item.name) or nil
            if definition and definition.weapon == true and (tonumber(item.count) or 0) > 0 then
                weapons[#weapons + 1] = {
                    slot = tonumber(item.slot),
                    name = item.name,
                    label = itemLabel(item, definition),
                    selected = selectedItem and tonumber(selectedItem.slot) == tonumber(item.slot) or false
                }
            end
        end
    end

    table.sort(weapons, function(left, right)
        return (left.slot or math.huge) < (right.slot or math.huge)
    end)

    local defaultItem, defaultDefinition = getWeaponSlot(source, DEFAULT_SLOT)

    return {
        ok = true,
        weapons = weapons,
        selectedSlot = selectedItem and tonumber(selectedItem.slot) or nil,
        defaultMode = defaultMode == true,
        defaultWeapon = defaultItem and {
            slot = DEFAULT_SLOT,
            name = defaultItem.name,
            label = itemLabel(defaultItem, defaultDefinition)
        } or false,
        payload = payload
    }
end

lib.callback.register('hope_backweapon:list', function(source)
    return listWeapons(source)
end)

lib.callback.register('hope_backweapon:select', function(source, requestedSlot)
    local now = GetGameTimer()
    if now - (lastSelectionAt[source] or 0) < 250 then
        return { ok = false, message = 'Patiente un instant avant de changer a nouveau.' }
    end
    lastSelectionAt[source] = now

    requestedSlot = tonumber(requestedSlot)
    if not requestedSlot or requestedSlot < 1 or requestedSlot % 1 ~= 0 then
        return { ok = false, message = 'Slot invalide.' }
    end

    if requestedSlot == DEFAULT_SLOT then
        selections[source] = nil
        local payload, item = syncPlayer(source)
        return {
            ok = true,
            payload = payload,
            message = item
                and ('%s du slot 1 sera affichee dans ton dos.'):format(itemLabel(item, getWeaponDefinition(item.name)))
                or 'Le slot 1 ne contient actuellement aucune arme.'
        }
    end

    local item, definition = getWeaponSlot(source, requestedSlot)
    if not item then
        return { ok = false, message = 'Cette arme n est plus dans ton inventaire.' }
    end

    selections[source] = {
        slot = requestedSlot,
        name = item.name,
        serial = itemSerial(item)
    }

    local payload = syncPlayer(source)
    return {
        ok = true,
        payload = payload,
        message = ('%s sera affichee dans ton dos.'):format(itemLabel(item, definition))
    }
end)

RegisterNetEvent('hope_backweapon:refresh', function()
    local source = source
    if refreshScheduled[source] then return end

    refreshScheduled[source] = true
    SetTimeout(math.max(50, tonumber(backConfig().inventoryRefreshDelay) or 125), function()
        refreshScheduled[source] = nil
        syncPlayer(source)
    end)
end)

AddEventHandler('playerDropped', function()
    local source = source
    selections[source] = nil
    replicatedSignatures[source] = nil
    refreshScheduled[source] = nil
    lastSelectionAt[source] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(1000, function()
        for _, playerId in ipairs(GetPlayers()) do
            syncPlayer(tonumber(playerId))
        end
    end)
end)

exports('RefreshBackWeapon', syncPlayer)
