-- QBX (server). Needs useExternalCharacters = true in qbx_core/config/client.lua,
-- otherwise qbx_core shows its own character menu as well.
local F = {}
local qbx = exports.qbx_core

function F.init() end

function F.isLoaded(src)
    return qbx:GetPlayer(src) ~= nil
end

function F.characters(src)
    local license2 = GetPlayerIdentifierByType(src, 'license2')
    local license = GetPlayerIdentifierByType(src, 'license')
    if not license2 and not license then return {} end
    local rows = MySQL.query.await('SELECT * FROM players WHERE license = ? OR license = ?', { license2 or license, license or license2 }) or {}
    local list = {}
    for _, row in ipairs(rows) do
        local info, money = Utils.decode(row.charinfo), Utils.decode(row.money)
        local job, gang = Utils.decode(row.job), Utils.decode(row.gang)
        local look = MySQL.single.await('SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { row.citizenid })
        list[#list + 1] = {
            slot = tonumber(row.cid) or tonumber(info.cid),
            id = row.citizenid,
            firstName = info.firstname,
            lastName = info.lastname,
            dob = BridgeUtil.isoDate(info.birthdate),
            gender = (tonumber(info.gender) == 1 or info.gender == 'female') and 'female' or 'male',
            nationality = info.nationality,
            phone = info.phone,
            cash = tonumber(money.cash) or 0,
            bank = tonumber(money.bank) or 0,
            job = job.label,
            grade = type(job.grade) == 'table' and job.grade.name or nil,
            gang = gang.name and gang.name ~= 'none' and gang.label or nil,
            lastPlayed = BridgeUtil.unix(row.last_logged_out) or BridgeUtil.unix(row.last_updated),
            model = look and look.model,
            skin = look and Utils.decode(look.skin),
        }
    end
    return list
end

-- Same starter items qbx_core hands out: starterItems in qbx_core/config/shared.lua.
local function giveStarterItems(src)
    if not Utils.started('ox_inventory') then return end
    local ok, shared = pcall(require, '@qbx_core.config.shared')
    local items = ok and type(shared) == 'table' and shared.starterItems
    if type(items) ~= 'table' then return end
    if not BridgeUtil.waitFor(function() return exports.ox_inventory:GetInventory(src) end, 10000) then return end
    for _, item in ipairs(items) do
        local meta = item.metadata
        if type(meta) == 'function' then
            local good, value = pcall(meta, src)
            meta = good and value or nil
        end
        exports.ox_inventory:AddItem(src, item.name, item.amount, meta)
    end
end

function F.login(src, character)
    if not qbx:Login(src, character.id) then return false end
    return BridgeUtil.waitFor(function() return qbx:GetPlayer(src) end, 10000) ~= nil
end

function F.create(src, slot, data)
    local newData = {
        cid = slot,
        charinfo = {
            firstname = data.firstName,
            lastname = data.lastName,
            birthdate = BridgeUtil.formatDate(data.dob, 'YYYY-MM-DD'),
            gender = data.gender == 'female' and 1 or 0,
            nationality = data.nationality,
            cid = slot,
        },
    }
    if not qbx:Login(src, nil, newData) then return false end
    if not BridgeUtil.waitFor(function() return qbx:GetPlayer(src) end, 10000) then return false end
    giveStarterItems(src)
    return true
end

function F.delete(_, character)
    qbx:DeleteCharacter(character.id)
    Wait(500)
    return true
end

function F.logout(src)
    qbx:Logout(src)
end

function F.position(src)
    local player = qbx:GetPlayer(src)
    local pos = player and player.PlayerData.position
    if not pos then return nil end
    return { x = pos.x, y = pos.y, z = pos.z, w = pos.w or 0.0 }
end

function F.citizenId(src)
    local player = qbx:GetPlayer(src)
    return player and player.PlayerData.citizenid
end

Frameworks.qbx = F
