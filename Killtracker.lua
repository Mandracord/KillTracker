_addon.name = 'KillTracker'
_addon.author = 'Meliora'
_addon.version = '1.0.1'
_addon.commands = {'kt', 'killtracker'}

-----------------------------------------------------------
-- Description
-- Basic Kill tracker for DRK unlock quest. 

-----------------------------------------------------------
-- Imports
-----------------------------------------------------------

config = require('config')
texts = require('texts')
packets = require('packets')

-----------------------------------------------------------
-- Defaults
-----------------------------------------------------------
local defaults = {
    kills = 0,
    pos = { x = 500, y = 200 },
    bg = T {
        alpha = 255, red = 0, green = 0, blue = 0,
        visible = false,
    },
    flags = T {
        bold = true
    },
    text = {
        font = 'Consolas',
        size = 12,
        bold = true,
        stroke = {
            width = 1,
            alpha = 255, red = 0, green = 0, blue = 0
        },
        red = 255, green = 255, blue = 255,
    },
}

settings = config.load(defaults)

-----------------------------------------------------------
-- Text object
-----------------------------------------------------------

local counter = texts.new(settings)
counter:pos(settings.pos.x, settings.pos.y)
counter:font(settings.text.font)
counter:size(settings.text.size)
counter:bold(settings.text.bold)
counter:stroke_width(settings.text.stroke.width)
counter:stroke_alpha(settings.text.stroke.alpha)
counter:show()

-----------------------------------------------------------
-- Helpers
-----------------------------------------------------------

local function get_equipped_weapon()
    local eq = windower.ffxi.get_items().equipment
    if not eq or not eq.main_bag or not eq.main or eq.main == 0 then
        return nil
    end

    local item = windower.ffxi.get_items(eq.main_bag, eq.main)
    if not item or not item.id or item.id == 0 then
        return nil
    end

    local res_items = require('resources').items
    local entry = res_items[item.id]
    if not entry or not entry.en then
        return nil
    end
    return entry.en
end

local function is_bringer_equipped()
    local name = get_equipped_weapon()
    if not name then return false end
    name = name:lower()
    return name == 'chaosbringer' or name == 'deathbringer'
end

-----------------------------------------------------------
-- HUD update
-----------------------------------------------------------

local function update_display()
    local c = settings.kills
    local remaining = math.max(100 - c, 0)

    local r,g,b = 255,255,255
    if c >= 100 then r,g,b = 0,255,0
    elseif c >= 80 then r,g,b = 255,0,0
    elseif c >= 60 then r,g,b = 255,128,0
    elseif c >= 40 then r,g,b = 255,255,0
    elseif c >= 20 then r,g,b = 128,255,255
    end

    local weapon_name = get_equipped_weapon() or 'None'

    local hud = string.format(
        "Counter for (%s)\n\n\\cs(%d,%d,%d)Kills: %d\\cr\nRemaining: %d",
        weapon_name, r,g,b, c, remaining
    )

    counter:text(hud)

    if c >= 100 then
        windower.add_to_chat(207, "[KillTracker] 100 kills reached! You're done.")
    end
end

-----------------------------------------------------------
-- Events
-----------------------------------------------------------

windower.register_event('incoming chunk', function(id, data)

    -- Equipment Changed (Update HUD)
    if id == 0x050 then
        update_display()
        return
    end

    if id ~= 0x029 then return end

    -- Kill detected, update counter
    local p = packets.parse('incoming', data)
    if not p or not p['Message'] then return end

    local player = windower.ffxi.get_player()
    if not player or not player.id then return end

    if is_bringer_equipped()
        and (p['Message'] == 6 or p['Message'] == 20)
        and p['Actor'] == player.id then
            settings.kills = settings.kills + 1
            config.save(settings)
            update_display()
            windower.add_to_chat(207,
                string.format('Kill registered (%d/100).', settings.kills))
    end
end)

windower.register_event('addon command', function(cmd)
    cmd = cmd and cmd:lower() or ''
    if cmd == 'reset' then
        settings.kills = 0
        config.save(settings)
        update_display()
        windower.add_to_chat(207, 'Counter reset.')
    elseif cmd == 'show' then
        counter:show()
    elseif cmd == 'hide' then
        counter:hide()
    else
        windower.add_to_chat(207, 'Commands: //kt reset | show | hide')
    end
end)

update_display()
