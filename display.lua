local display = {}

local texts = require('texts')
local currency = require('currency')
local tracker = require('tracker')
local parser = require('parser')

local display_box

local default_settings = {
    pos = {x = 100, y = 100},
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
    display_box = texts.new(default_settings)
    display_box:show()
end

function display.update()
    if not display_box then return end

    -- Update Progression Box
    local state = tracker.get_state()
    local total_galli = currency.display_values()
    
    local prog_lines = {}
    table.insert(prog_lines, "\\cs(100,200,200)[ Sortie Progression ]\\cr")
    table.insert(prog_lines, string.format("\\cs(255,255,255)Gallimaufry Stored: \\cr\\cs(225,150,0)%s\\cr", comma_value(total_galli)))
    table.insert(prog_lines, string.format("\\cs(255,255,255)Run Accumulation:   \\cr\\cs(225,150,0)+%s\\cr", comma_value(state.run_gallimaufry)))
    
    table.insert(prog_lines, "")
    table.insert(prog_lines, "\\cs(100,200,200)[ Objectives ]\\cr")
    local sectors = {"A", "B", "C", "D", "E", "F", "G", "H"}
    for _, s in ipairs(sectors) do
        local mini_boss = nil
        local sector_boss = nil
        for _, b in ipairs(state.bosses_killed) do
            if b.sector == s then
                if b.type == "mini" then
                    mini_boss = b.name
                elseif b.type == "main" then
                    sector_boss = b.name
                else
                    if not sector_boss then sector_boss = b.name end
                end
            end
        end
        
        local sec_items = {}
        if state.sectors[s] and state.sectors[s].items then
            for _, i in ipairs(state.sectors[s].items) do
                table.insert(sec_items, i)
            end
        end
        
        local elements = {}
        if #sec_items > 0 then
            table.insert(elements, "\\cs(150,225,150)" .. table.concat(sec_items, ", ") .. "\\cr")
        end
        if mini_boss then
            if #elements > 0 then
                table.insert(elements, "\\cs(100,100,100)-\\cr")
            end
            table.insert(elements, "\\cs(225,150,0)" .. mini_boss .. "\\cr")
        end
        if sector_boss then
            if #elements > 0 then
                table.insert(elements, "\\cs(100,100,100)--\\cr")
            end
            table.insert(elements, "\\cs(225,150,0)" .. sector_boss .. "\\cr")
        end
        
        if #elements > 0 then
            table.insert(prog_lines, string.format("\\cs(255,255,255)%s:\\cr %s", s, table.concat(elements, " ")))
        else
            table.insert(prog_lines, string.format("\\cs(255,255,255)%s:\\cr \\cs(100,100,100)-\\cr", s))
        end
    end

    local other_objs = {}
    if state.other["Ground Aurum"] > 0 then table.insert(other_objs, string.format("G.Aurum: \\cs(225,150,0)%d\\cr", state.other["Ground Aurum"])) end
    if state.other["Basement Aurum"] > 0 then table.insert(other_objs, string.format("B.Aurum: \\cs(225,150,0)%d\\cr", state.other["Basement Aurum"])) end
    if state.other["G Seal"] > 0 then table.insert(other_objs, string.format("G.Seal: \\cs(225,150,0)%d\\cr", state.other["G Seal"])) end
    if #other_objs > 0 then
        table.insert(prog_lines, "\\cs(255,255,255)" .. table.concat(other_objs, " | ") .. "\\cr")
    end

    if state.cases["Old Case"] > 0 or state.cases["Old Case +1"] > 0 or state.cases["Old Case +2"] > 0 then
        table.insert(prog_lines, "")
        table.insert(prog_lines, "\\cs(100,200,200)[ Cases ]\\cr")
        local cases = {}
        if state.cases["Old Case"] > 0 then table.insert(cases, "NQ: \\cs(225,150,0)" .. state.cases["Old Case"] .. "\\cr") end
        if state.cases["Old Case +1"] > 0 then table.insert(cases, "+1: \\cs(225,150,0)" .. state.cases["Old Case +1"] .. "\\cr") end
        if state.cases["Old Case +2"] > 0 then table.insert(cases, "+2: \\cs(225,150,0)" .. state.cases["Old Case +2"] .. "\\cr") end
        table.insert(prog_lines, "\\cs(255,255,255)" .. table.concat(cases, " | ") .. "\\cr")
    end

    table.insert(prog_lines, "")
    
    local p_data = parser.get_damage_data()

    table.insert(prog_lines, "\\cs(100,200,200)[ Sortie Performance ]\\cr")
    table.insert(prog_lines, string.format("\\cs(225,150,0)%-14s %-10s %-7s %-7s %-8s\\cr", "Player", "Damage", "Dmg %", "Acc %", "WS Avg"))
    
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
            
            table.insert(prog_lines, p_str)
        end
    else
        table.insert(prog_lines, "\\cs(255,255,255)No combat data.\\cr")
    end

    display_box:text(table.concat(prog_lines, "\n"))
end

function display.show()
    if display_box then display_box:show() end
end

function display.hide()
    if display_box then display_box:hide() end
end

return display
