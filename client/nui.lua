-- Talking to the character screen UI (web/src).
Nui = {}

function Nui.send(action, data)
    SendNUIMessage({ action = action, data = data })
end

-- Config.Logo as a link the UI can load, or nil for the default logo.
function Nui.logo()
    local logo = Config.Logo
    if type(logo) ~= 'string' or logo == '' then return nil end
    if logo:find('^https?://') or logo:find('^nui://') then return logo end
    return ('https://cfx-nui-%s/%s'):format(GetCurrentResourceName(), (logo:gsub('\\', '/'):gsub('^/+', '')))
end

-- The black blades in the UI (web/src/components/Shutter.tsx). label shows under the logo while shut.
function Nui.shutter(closed, label)
    Nui.send('shutter', { closed = closed == true, label = label })
end

function Nui.focus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

-- RegisterNUICallback that always answers, even when the handler throws.
function Nui.on(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = pcall(handler, type(data) == 'table' and data or {})
        if not ok then
            print(('^1[bakery_multicharacter] %s: %s^7'):format(name, result))
            return cb({ ok = false, error = 'Something went wrong.' })
        end
        cb(result == nil and { ok = true } or result)
    end)
end
