local report = {}

local currency = require('currency')
local tracker = require('tracker')
local parser = require('parser')
local json = require('dkjson')

local webhook_url = "ADD YOUR WEBHOOK HERE"

local function comma_value(n)
    if not n then return "0" end
    local left, num, right = tostring(n):match('^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

local function save_report_file(contents)
    local filename = string.format('sortie_%s.txt', os.date('%Y-%m-%d_%H-%M-%S'))
    local path = windower.addon_path .. 'data/' .. filename

    local f = io.open(path, 'w')
    if f then
        f:write(table.concat(contents, '\n'))
        f:close()
        windower.add_to_chat(207, ('[SortieTracker] Report saved to: data/%s'):format(filename))
    else
        windower.add_to_chat(123, '[SortieTracker] Failed to write sortie report file.')
    end
end

local function send_to_discord(message)
    if type(message) == "table" then
        message = table.concat(message, "\n")
    elseif type(message) ~= "string" then
        windower.add_to_chat(123, "[Discord] Invalid message type: " .. type(message))
        return
    end

    local formatted = '```\n' .. message .. '\n```'
    
    local payload_table = {
        content = formatted
    }

    local payload = json.encode(payload_table)

    local response_body = {}
    local https = require("ssl.https")
    local ltn12 = require("ltn12")
    local result, status_code, headers, status_line = https.request{
        url = webhook_url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#payload)
        },
        source = ltn12.source.string(payload),
        sink = ltn12.sink.table(response_body)
    }

    if status_code == 204 then
        windower.add_to_chat(207, "[Discord] Message sent successfully.")
    else
        windower.add_to_chat(123, "[Discord] Failed to send: " .. (status_line or "Unknown error"))
    end
end



function report.generate(additional_note, push_to_discord)
    local state = tracker.get_state()
    local total_galli = currency.display_values()
    local p_data = parser.get_damage_data()

    local lines = {}
    table.insert(lines, ('[Sortie Report - %s]'):format(os.date()))
    table.insert(lines, ('Total Gallimaufry: %s'):format(comma_value(total_galli)))
    table.insert(lines, ('Run Accumulation: +%s'):format(comma_value(state.run_gallimaufry)))
    table.insert(lines, "-----------------------------")

    table.insert(lines, "[ == Objectives == ]")
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
            table.insert(elements, table.concat(sec_items, ", "))
        end
        if mini_boss then
            if #elements > 0 then table.insert(elements, "-") end
            table.insert(elements, mini_boss)
        end
        if sector_boss then
            if #elements > 0 then table.insert(elements, "--") end
            table.insert(elements, sector_boss)
        end
        
        if #elements > 0 then
            table.insert(lines, string.format("%s: %s", s, table.concat(elements, " ")))
        else
            table.insert(lines, string.format("%s: -", s))
        end
    end
    
    table.insert(lines, "Ground Aurum: " .. (state.other["Ground Aurum"] or 0))
    table.insert(lines, "Basement Aurum: " .. (state.other["Basement Aurum"] or 0))
    table.insert(lines, "G Seal: " .. (state.other["G Seal"] or 0))
    table.insert(lines, "-----------------------------")
    
    table.insert(lines, "[ Cases ]")
    table.insert(lines, "Old Case: " .. (state.cases["Old Case"] or 0))
    table.insert(lines, "Old Case +1: " .. (state.cases["Old Case +1"] or 0))
    table.insert(lines, "Old Case +2: " .. (state.cases["Old Case +2"] or 0))
    table.insert(lines, "-----------------------------")

    table.insert(lines, "[ Sortie Performance ]")
    table.insert(lines, string.format("%-14s %-9s %-10s %-7s %-7s %-8s", "Player", "Job", "Damage", "Dmg %", "Acc %", "WS Avg"))
    if p_data.total > 0 then
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

            local job_str = ""
            if p_data.jobs and p_data.jobs[p.name] then
                job_str = string.format("%s/%s", p_data.jobs[p.name].main, p_data.jobs[p.name].sub)
            end

            table.insert(lines, string.format("%-14s %-9s %-10s %-7.1f %-7.1f %-8s", string.sub(p.name, 1, 13), string.sub(job_str, 1, 8), comma_value(p.dmg), pct, acc_pct, comma_value(ws_avg)))
        end
        
        local sc_strings = {}
        for i, p in ipairs(sorted_players) do
            local sc_dmg = p_data.players[p.name].sc_damage or 0
            if sc_dmg > 0 then
                table.insert(sc_strings, string.format("  %-12s %s", string.sub(p.name, 1, 12), comma_value(sc_dmg)))
            end
        end
        if #sc_strings > 0 then
            table.insert(lines, "Skillchains:")
            for _, sc in ipairs(sc_strings) do
                table.insert(lines, sc)
            end
        end
    else
        table.insert(lines, "No combat data.")
    end
    table.insert(lines, "-----------------------------")

    table.insert(lines, '[Extra Notes/Mentions]')
    table.insert(lines, additional_note)

    save_report_file(lines)

    if push_to_discord then
        send_to_discord(lines)
    end
end

return report
