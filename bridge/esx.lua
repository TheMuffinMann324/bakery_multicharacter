-- ESX Legacy (server).
-- ESX only hands character loading to a multicharacter script when its Config.Multichar is on.
-- fxmanifest.lua provides "esx_multicharacter", which switches that on by itself; if your ESX
-- version doesn't pick it up, set Config.Multichar = true in es_extended's config.
local ESX
local F = {}
local deleteTargets = {}   -- { { table, column } } every table that stores a character identifier

local function prefix() return Config.ESX.Prefix or 'char' end

-- License without the "license:" part, the way ESX builds identifiers.
local function baseIdentifier(src)
    local id = ESX.GetIdentifier and ESX.GetIdentifier(src)
    if not id then
        id = GetPlayerIdentifierByType(src, 'license')
        id = id and id:gsub('^license:', '')
    end
    return id
end

function F.init()
    ESX = exports.es_extended:getSharedObject()

    local cfg = ESX.GetConfig and ESX.GetConfig()
    if cfg and cfg.Multichar == false then
        print('^1[bakery_multicharacter] es_extended has Config.Multichar off. Set Config.Multichar = true in es_extended\'s config and remove esx_multicharacter.^7')
    end

    -- Tables with an "identifier" or "owner" column hold character data; they are cleared on delete.
    MySQL.query('SELECT TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME IN (?, ?) AND DATA_TYPE IN (?, ?)',
        { 'identifier', 'owner', 'varchar', 'char' }, function(rows)
            for _, row in ipairs(rows or {}) do
                deleteTargets[#deleteTargets + 1] = { row.TABLE_NAME, row.COLUMN_NAME }
            end
            Utils.debug(('%d tables are cleared when a character is deleted'):format(#deleteTargets))
        end)
end

function F.isLoaded(src)
    return ESX.GetPlayerFromId(src) ~= nil
end

function F.characters(src)
    local base = baseIdentifier(src)
    if not base then return {} end
    local rows = MySQL.query.await('SELECT * FROM users WHERE identifier LIKE ?', { ('%s%%:%s'):format(prefix(), base) }) or {}
    local jobs = ESX.GetJobs and ESX.GetJobs() or {}
    local list = {}
    for _, row in ipairs(rows) do
        local slot = tonumber(row.identifier:match('^' .. prefix() .. '(%d+):'))
        if slot then
            local accounts = Utils.decode(row.accounts)
            local job = jobs[row.job]
            local grade = job and job.grades and job.grades[tostring(row.job_grade)]
            local skin = Utils.decode(row.skin)
            list[#list + 1] = {
                slot = slot,
                id = row.identifier,
                firstName = row.firstname,
                lastName = row.lastname,
                dob = BridgeUtil.isoDate(row.dateofbirth, Config.ESX.DateFormat),
                gender = (row.sex == 'f' or row.sex == 'F') and 'female' or 'male',
                phone = row.phone_number and tostring(row.phone_number) or nil,
                height = tonumber(row.height),
                cash = tonumber(accounts.money) or 0,
                bank = tonumber(accounts.bank) or 0,
                job = job and job.label or row.job,
                grade = grade and grade.label or nil,
                lastPlayed = BridgeUtil.unix(row.last_seen),
                disabled = row.disabled == 1 or row.disabled == true,
                model = skin.model,
                skin = next(skin) and skin or nil,
            }
        end
    end
    return list
end

local function alreadyOnline(identifier)
    return ESX.GetPlayerFromIdentifier and ESX.GetPlayerFromIdentifier(identifier) ~= nil
end

-- es_extended loads the character and then sends esx:playerLoaded to the client, where
-- bridge/client.lua places the player in the world.
function F.login(src, character)
    if alreadyOnline(character.id) then return false end
    TriggerEvent('esx:onPlayerJoined', src, character.id:match('^(.-):'))
    return true
end

function F.create(src, slot, data)
    local identifier = ('%s%d:%s'):format(prefix(), slot, baseIdentifier(src))
    if alreadyOnline(identifier) then return false end
    TriggerEvent('esx:onPlayerJoined', src, prefix() .. slot, {
        firstname = data.firstName,
        lastname = data.lastName,
        dateofbirth = BridgeUtil.formatDate(data.dob, Config.ESX.DateFormat or 'DD/MM/YYYY'),
        sex = data.gender == 'female' and 'f' or 'm',
        height = data.height,
    })
    return true
end

function F.delete(_, character)
    local queries = {}
    for _, target in ipairs(deleteTargets) do
        queries[#queries + 1] = { query = ('DELETE FROM `%s` WHERE `%s` = ?'):format(target[1], target[2]), values = { character.id } }
    end
    if #queries == 0 then
        queries[1] = { query = 'DELETE FROM `users` WHERE `identifier` = ?', values = { character.id } }
    end
    return MySQL.transaction.await(queries) and true or false
end

function F.logout(src)
    TriggerEvent('esx:playerLogout', src)
end

function F.position() return nil end   -- esx:playerLoaded carries the coords

function F.citizenId(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier
end

Frameworks.esx = F
