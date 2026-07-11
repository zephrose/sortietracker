local display = {}

local texts = require('texts')
local currency = require('currency')
local tracker = require('tracker')
local parser = require('parser')

local progression_box
local parse_box

local default_progression_settings = {
    pos = {x = 100, y = 100},
    bg = {visible = true, alpha = 150, red = 0, green = 0, blue = 0},
    text = {size = 10, font = "Consolas", alpha = 255, red = 255, green = 255, blue = 255},
    padding = 4,
    flags = {draggable = true}
}

local default_parse_settings = {
    pos = {x = 100, y = 400},
    bg = {visible = true, alpha = 150, red = 0, green = 0, blue = 0},
    text = {size = 10, font = "Consolas", alpha = 255, red = 255, green = 255, blue = 255},
    padding = 4,
    flags = {draggable = true}
}

-- Format numbers with commas
local function comma_value(n)
    if not n then return "0" end
    local left, num, right = tostring(n):match('^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

function display.init()
    progression_box = texts.new(default_progression_settings)
    parse_box = texts.new(default_parse_settings)
    progression_box:show()
    parse_box:show()
end

function display.update()
    if not progression_box or not parse_box then return end

    -- Update Progression Box
    local state = tracker.get_state()
    local total_galli = currency.display_values()
    
    local prog_lines = {}
    table.insert(prog_lines, "\\cs(100,200,200)[ Sortie Progression ]\\cr")
    table.insert(prog_lines, string.format("\\cs(255,255,255)Gallimaufry Stored: \\cr\\cs(225,150,0)%s\\cr", comma_value(total_galli)))
    table.insert(prog_lines, string.format("\\cs(255,255,255)Run Accumulation:   \\cr\\cs(225,150,0)+%s\\cr", comma_value(state.run_gallimaufry)))
    
    if #state.bosses_killed > 0 then
        table.insert(prog_lines, "")
        table.insert(prog_lines, "\\cs(100,200,200)[ Bosses Defeated ]\\cr")
        for _, b in ipairs(state.bosses_killed) do
            table.insert(prog_lines, string.format("\\cs(225,150,0)%s\\cr \\cs(255,255,255)- %s\\cr", b.time, b.name))
        end
    end

    if #state.chests_opened > 0 then
        table.insert(prog_lines, "")
        table.insert(prog_lines, "\\cs(100,200,200)[ Chests & Coffers ]\\cr")
        for _, c in ipairs(state.chests_opened) do
            table.insert(prog_lines, string.format("\\cs(225,150,0)%s\\cr \\cs(255,255,255)- %s\\cr", c.time, c.name))
        end
    end

    if state.temp_items and #state.temp_items > 0 then
        table.insert(prog_lines, "")
        table.insert(prog_lines, "\\cs(100,200,200)[ Temp Items ]\\cr")
        for _, t in ipairs(state.temp_items) do
            table.insert(prog_lines, string.format("\\cs(225,150,0)%s\\cr \\cs(255,255,255)- %s\\cr", t.time, t.name))
        end
    end

    progression_box:text(table.concat(prog_lines, "\n"))

    -- Update Parse Box
    local p_data = parser.get_damage_data()
    local parse_lines = {}
    table.insert(parse_lines, "\\cs(100,200,200)[ Sortie Performance ]\\cr")
    table.insert(parse_lines, string.format("\\cs(225,150,0)%-14s %-10s %-7s %-7s %-8s\\cr", "Player", "Damage", "Dmg %", "Acc %", "WS Avg"))
    
    if p_data.total > 0 then
        -- Sort players by damage
        local sorted_players = {}
        for name, data in pairs(p_data.players) do
            table.insert(sorted_players, {name = name, dmg = data.damage, hits = data.hits, misses = data.misses, ws_damage = data.ws_damage, ws_count = data.ws_count})
        end
        table.sort(sorted_players, function(a, b) return a.dmg > b.dmg end)

        for i, p in ipairs(sorted_players) do
            local pct = (p.dmg / p_data.total) * 100
            
            local acc_pct = 0
            local total_swings = p.hits + p.misses
            if total_swings > 0 then
                acc_pct = (p.hits / total_swings) * 100
            end
            
            local ws_avg = 0
            if p.ws_count > 0 then
                ws_avg = math.floor(p.ws_damage / p.ws_count)
            end
            
            local p_str = string.format("\\cs(100,200,200)%-14s\\cr \\cs(255,255,255)%-10s %-7.1f %-7.1f %-8s\\cr", 
                string.sub(p.name, 1, 13), comma_value(p.dmg), pct, acc_pct, comma_value(ws_avg))
            
            table.insert(parse_lines, p_str)
        end
    else
        table.insert(parse_lines, "\\cs(255,255,255)No combat data.\\cr")
    end

    parse_box:text(table.concat(parse_lines, "\n"))
end

function display.show()
    if progression_box then progression_box:show() end
    if parse_box then parse_box:show() end
end

function display.hide()
    if progression_box then progression_box:hide() end
    if parse_box then parse_box:hide() end
end

return display
