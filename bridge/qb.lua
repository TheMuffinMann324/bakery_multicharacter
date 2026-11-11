-- QBCore (server).
local QBCore
local F = {}

function F.init()
    QBCore = exports['qb-core']:GetCoreObject()
end

function F.isLoaded(src)
    return QBCore.Functions.GetPlayer(src) ~= nil
end

function F.characters(src)
    local license = QBCore.Functions.GetIdentifier(src, 'license')
    if not license then return {} end
    local rows = MySQL.query.await('SELECT * FROM players WHERE license = ?', { license }) or {}
    local list = {}
    for _, row in ipairs(rows) do
        local info, money = Utils.decode(row.charinfo), Utils.decode(row.money)
        local job, gang = Utils.decode(row.job), Utils.decode(row.gang)
        local look = MySQL.single.await('SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { row.citizenid })
        list[#list + 1] = {
            slot = tonumber(row.cid),
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
            lastPlayed = BridgeUtil.unix(row.last_updated),
            model = look and look.model,
            skin = look and Utils.decode(look.skin),
        }
    end
    return list
end

-- qb-houses wants its house list sent to every player that loads in.
local function loadHouseData(src)
    if not Utils.started('qb-houses') then return end
    local houses, garages = {}, {}
    local ok, rows = pcall(function() return MySQL.query.await('SELECT * FROM houselocations') end)
    if not ok or not rows then return end
    for _, v in ipairs(rows) do
        local garage = v.garage and Utils.decode(v.garage) or {}
        houses[v.name] = {
            coords = Utils.decode(v.coords), owned = tonumber(v.owned) == 1, price = v.price, locked = true,
            adress = v.label, tier = v.tier, garage = garage, decorations = {},
        }
        garages[v.name] = { label = v.label, takeVehicle = garage }
    end
    TriggerClientEvent('qb-garages:client:houseGarageConfig', src, garages)
    TriggerClientEvent('qb-houses:client:setHouseConfig', src, houses)
end

-- Same items qb-multicharacter hands out: QBCore.Shared.StarterItems (qb-core/shared/main.lua).
local function giveStarterItems(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player or type(QBCore.Shared.StarterItems) ~= 'table' then return end
    local info = player.PlayerData.charinfo
    for _, v in pairs(QBCore.Shared.StarterItems) do
        local meta = {}
        if v.item == 'id_card' then
            meta = {
                citizenid = player.PlayerData.citizenid, firstname = info.firstname, lastname = info.lastname,
                birthdate = info.birthdate, gender = info.gender, nationality = info.nationality,
            }
        elseif v.item == 'driver_license' then
            meta = { firstname = info.firstname, lastname = info.lastname, birthdate = info.birthdate, type = 'Class C Driver License' }
        end
        player.Functions.AddItem(v.item, v.amount, false, meta)
    end
end

local function afterLogin(src)
    local player = BridgeUtil.waitFor(function() return QBCore.Functions.GetPlayer(src) end, 10000)
    if not player then return false end
    Wait(500)   -- let other resources finish their own player-loaded work
    QBCore.Commands.Refresh(src)
    loadHouseData(src)
    return true
end

function F.login(src, character)
    if not QBCore.Player.Login(src, character.id) then return false end
    return afterLogin(src)
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
    if not QBCore.Player.Login(src, false, newData) then return false end
    if not afterLogin(src) then return false end
    giveStarterItems(src)
    return true
end

function F.delete(src, character)
    QBCore.Player.DeleteCharacter(src, character.id)
    Wait(500)   -- the delete runs as a transaction in the background
    return true
end

function F.logout(src)
    QBCore.Player.Logout(src)
end

function F.position(src)
    local player = QBCore.Functions.GetPlayer(src)
    local pos = player and player.PlayerData.position
    if not pos then return nil end
    return { x = pos.x, y = pos.y, z = pos.z, w = pos.w or pos.a or 0.0 }
end

function F.citizenId(src)
    local player = QBCore.Functions.GetPlayer(src)
    return player and player.PlayerData.citizenid
end

Frameworks.qb = F
