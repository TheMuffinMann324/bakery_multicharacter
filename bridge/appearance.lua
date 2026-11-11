-- Dressing the preview characters (client). Edit this file if your clothing resource isn't covered.
--
-- Saved looks come in three shapes:
--   appearance  illenium-appearance / fivem-appearance  (has .components / .headBlend)
--   qb-clothing { ["t-shirt"] = { item, texture }, ... }
--   skinchanger { tshirt_1, tshirt_2, sex, ... }  (ESX)
Appearance = {}

local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`

-- Use your own clothing resource: return true when you dressed the ped yourself.
---@param ped number
---@param skin table
---@return boolean
function Appearance.custom(ped, skin)
    return false
end

-- Model hash for a saved character.
function Appearance.model(character)
    local model = character.model
    local skin = character.skin
    if type(skin) == 'table' and skin.model then model = skin.model end
    if type(model) == 'string' then model = tonumber(model) or joaat(model) end
    if type(model) == 'number' and model ~= 0 and IsModelInCdimage(model) then return model end
    if type(skin) == 'table' and skin.sex ~= nil then
        return tonumber(skin.sex) == 1 and FEMALE or MALE
    end
    return character.gender == 'female' and FEMALE or MALE
end

function Appearance.emptyModel(gender)
    return gender == 'female' and FEMALE or MALE
end

-- A plain look, so a freemode ped never shows up without a face.
function Appearance.default(ped)
    SetPedDefaultComponentVariation(ped)
    local model = GetEntityModel(ped)
    if model == MALE or model == FEMALE then
        SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, false)
    end
end

-- ------------------------------------------------------------
-- skinchanger (ESX) applied to any ped. skinchanger itself only dresses the player.
-- ------------------------------------------------------------
local COMPONENTS = {
    { 8, 'tshirt_1', 'tshirt_2' }, { 11, 'torso_1', 'torso_2' }, { 10, 'decals_1', 'decals_2' },
    { 3, 'arms', 'arms_2' }, { 4, 'pants_1', 'pants_2' }, { 6, 'shoes_1', 'shoes_2' },
    { 1, 'mask_1', 'mask_2' }, { 9, 'bproof_1', 'bproof_2' }, { 7, 'chain_1', 'chain_2' },
    { 5, 'bags_1', 'bags_2' },
}
local PROPS = {
    { 0, 'helmet_1', 'helmet_2' }, { 1, 'glasses_1', 'glasses_2' }, { 2, 'ears_1', 'ears_2' },
    { 6, 'watches_1', 'watches_2' }, { 7, 'bracelets_1', 'bracelets_2' },
}
-- overlay id, style key, opacity key, colour type, colour key, second colour key
local OVERLAYS = {
    { 0, 'blemishes_1', 'blemishes_2' }, { 1, 'beard_1', 'beard_2', 1, 'beard_3', 'beard_4' },
    { 2, 'eyebrows_1', 'eyebrows_2', 1, 'eyebrows_3', 'eyebrows_4' }, { 3, 'age_1', 'age_2' },
    { 4, 'makeup_1', 'makeup_2', 2, 'makeup_3', 'makeup_4' }, { 5, 'blush_1', 'blush_2', 2, 'blush_3' },
    { 6, 'complexion_1', 'complexion_2' }, { 7, 'sun_1', 'sun_2' },
    { 8, 'lipstick_1', 'lipstick_2', 1, 'lipstick_3', 'lipstick_4' }, { 9, 'moles_1', 'moles_2' },
    { 10, 'chest_1', 'chest_2', 1, 'chest_3' }, { 11, 'bodyb_1', 'bodyb_2' }, { 12, 'bodyb_3', 'bodyb_4' },
}
local FEATURES = {
    'nose_1', 'nose_2', 'nose_3', 'nose_4', 'nose_5', 'nose_6', 'eyebrows_5', 'eyebrows_6',
    'cheeks_1', 'cheeks_2', 'cheeks_3', 'eye_squint', 'lip_thickness', 'jaw_1', 'jaw_2',
    'chin_1', 'chin_2', 'chin_3', 'chin_4', 'neck_thickness',
}

local function n(value, fallback)
    return tonumber(value) or fallback or 0
end

local function applySkinchanger(ped, s)
    if s.mom or s.dad then
        SetPedHeadBlendData(ped, n(s.mom), n(s.dad), 0, n(s.mom), n(s.dad), 0, n(s.face_md_weight, 50) / 100.0, n(s.skin_md_weight, 50) / 100.0, 0.0, false)
    else
        SetPedHeadBlendData(ped, n(s.face), n(s.face), n(s.face), n(s.skin), n(s.skin), n(s.skin), 1.0, 1.0, 1.0, true)
    end
    for i, key in ipairs(FEATURES) do
        if s[key] then SetPedFaceFeature(ped, i - 1, n(s[key]) / 10.0) end
    end
    SetPedComponentVariation(ped, 2, n(s.hair_1), n(s.hair_2), 2)
    SetPedHairColor(ped, n(s.hair_color_1), n(s.hair_color_2))
    if s.eye_color then SetPedEyeColor(ped, n(s.eye_color)) end
    for _, o in ipairs(OVERLAYS) do
        if s[o[2]] then
            SetPedHeadOverlay(ped, o[1], n(s[o[2]]), n(s[o[3]]) / 10.0)
            if o[4] then SetPedHeadOverlayColor(ped, o[1], o[4], n(s[o[5]]), n(o[6] and s[o[6]])) end
        end
    end
    for _, c in ipairs(COMPONENTS) do
        if s[c[2]] then SetPedComponentVariation(ped, c[1], n(s[c[2]]), n(s[c[3]]), 2) end
    end
    for _, p in ipairs(PROPS) do
        local drawable = tonumber(s[p[2]])
        if drawable then
            if drawable < 0 then ClearPedProp(ped, p[1]) else SetPedPropIndex(ped, p[1], drawable, n(s[p[3]]), true) end
        end
    end
end

-- ------------------------------------------------------------
-- Dress a preview ped with a saved look.
-- ------------------------------------------------------------
function Appearance.apply(ped, skin)
    if type(skin) ~= 'table' or not next(skin) then return end
    local ok, err = pcall(function()
        if Appearance.custom(ped, skin) then return end

        if skin.components or skin.headBlend then
            if Utils.started('illenium-appearance') then
                exports['illenium-appearance']:setPedAppearance(ped, skin)
            elseif Utils.started('fivem-appearance') then
                exports['fivem-appearance']:setPedAppearance(ped, skin)
            end
            return
        end

        if skin.tshirt_1 or skin.torso_1 or skin.sex ~= nil then
            applySkinchanger(ped, skin)
            return
        end

        -- qb-clothing takes the ped as its second argument
        TriggerEvent('qb-clothing:client:loadPlayerClothing', skin, ped)
    end)
    if not ok then Utils.debug('could not dress a preview ped: ' .. tostring(err)) end
end

-- Give the player the model their saved look needs (ESX; QBCore / QBX clothing resources do this themselves).
function Appearance.setPlayerModel(model)
    if not model or model == 0 or GetEntityModel(PlayerPedId()) == model then return end
    if not IsModelInCdimage(model) then return end
    RequestModel(model)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) then return end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    Appearance.default(PlayerPedId())
end
