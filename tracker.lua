local tracker = {}

local files = require('files')
package.path = package.path .. ';' .. windower.addon_path .. 'libs/?.lua'
local json = require('dkjson')

local state = {
    run_gallimaufry = 0,
    bosses_killed = {}, -- {name = "Aminon", time = "10:15:22"}
    chests_opened = {}, -- {name = "Aurum Coffer", time = "10:20:10"}
    temp_items = {},    -- {name = "Ra'Kaznar Plate A", time = "10:25:00"}
    boss_list = {},
    chest_list = {},
    cases = { ["Old Case"] = 0, ["Old Case +1"] = 0, ["Old Case +2"] = 0 },
    sectors = {
        A = { Ch = 0, Ca = 0, Co = 0 }, B = { Ch = 0, Ca = 0, Co = 0 },
        C = { Ch = 0, Ca = 0, Co = 0 }, D = { Ch = 0, Ca = 0, Co = 0 },
        E = { Ch = 0, Ca = 0, Co = 0 }, F = { Ch = 0, Ca = 0, Co = 0 },
        G = { Ch = 0, Ca = 0, Co = 0 }, H = { Ch = 0, Ca = 0, Co = 0 }
    },
    other = { ["Ground Aurum"] = 0, ["Basement Aurum"] = 0, ["G Seal"] = 0 },
    current_sector = "A"
}

local function load_json(filepath)
    local f = io.open(windower.addon_path .. filepath, 'r')
    if not f then return nil end
    local content = f:read('*a')
    f:close()
    local obj, pos, err = json.decode(content, 1, nil)
    if err then
        print('Error parsing JSON: ' .. err)
    end
    return obj
end

function tracker.init()
    local nms_data = load_json('data/sortie_nms.json')
    local obj_data = load_json('data/sortie_objectives.json')

    if nms_data and nms_data.sortie_bosses then
        for _, minor in ipairs(nms_data.sortie_bosses.minor_nms or {}) do
            state.boss_list[minor.nm:lower()] = {name = minor.nm, type = "mini", sector = minor.sector}
        end
        for _, major in ipairs(nms_data.sortie_bosses.major_nms or {}) do
            state.boss_list[major.nm:lower()] = {name = major.nm, type = "main", sector = major.sector}
        end
    end
end

local function get_time_string()
    return os.date('%H:%M:%S')
end

-- Chat hook to track progress
windower.register_event('incoming text', function(original, modified, mode)
    -- Clean control codes from the incoming line
    local cleaned_line = original:gsub('\30[%d%a]', ''):gsub('\31', ''):gsub('[\r\n]', '')
    
    -- Modes 121, 123, 10, 12, 13, 14, 5 for system messages, combat messages etc.
    -- Tracking Gallimaufry and Coffer/Casket fallbacks
    local player_name, amount = cleaned_line:match("([%a%-']+)%s+received%s+(%d+)%s+gallimaufry%s+for%s+a%s+total%s+of%s+%d+%.*")
    if player_name and amount then
        local amt = tonumber(amount)
        state.run_gallimaufry = state.run_gallimaufry + amt
        
        -- Fallback for caskets/coffers if spawn message missed (rarely needed, but safe)
        if amt == 300 then
            state.sectors[state.current_sector].Ca = state.sectors[state.current_sector].Ca + 1
        elseif amt == 500 then
            state.sectors[state.current_sector].Co = state.sectors[state.current_sector].Co + 1
        elseif amt == 1000 then
            state.other["Ground Aurum"] = state.other["Ground Aurum"] + 1
        elseif amt == 1500 then
            state.sectors[state.current_sector].Co = state.sectors[state.current_sector].Co + 1
        elseif amt == 3000 then
            state.other["Basement Aurum"] = state.other["Basement Aurum"] + 1
        end
    end

    -- Tracking Chest Spawns
    local clower = cleaned_line:lower()
    if clower:find("treasure casket appears") then
        if state.sectors[state.current_sector] then state.sectors[state.current_sector].Ca = state.sectors[state.current_sector].Ca + 1 end
    elseif clower:find("treasure coffer appears") then
        if state.sectors[state.current_sector] then state.sectors[state.current_sector].Co = state.sectors[state.current_sector].Co + 1 end
    elseif clower:find("aurum strongbox appears") or clower:find("aurum coffer appears") then
        if state.current_sector:match("[A-D]") then
            state.other["Ground Aurum"] = state.other["Ground Aurum"] + 1
        else
            state.other["Basement Aurum"] = state.other["Basement Aurum"] + 1
        end
    end

    -- Tracking Old Cases
    if cleaned_line:lower():find("obtained:.*old case") then
        local case_name = cleaned_line:match("obtained:.*(Old Case[^%.]*)")
        if case_name then
            case_name = case_name:gsub('^%s*(.-)%s*$', '%1'):gsub('[^%w%s%+]', '')
            if state.cases[case_name] ~= nil then
                state.cases[case_name] = state.cases[case_name] + 1
            else
                state.cases["Old Case"] = state.cases["Old Case"] + 1
            end
        else
            state.cases["Old Case"] = state.cases["Old Case"] + 1
        end
    end

    -- Tracking Temporary Items (Chests)
    local temp_item = cleaned_line:match("temporary item:%s+([^%.]+)%.?")
    if temp_item then
        -- Clean character garbage (keep letters, numbers, spaces, #, -, ')
        temp_item = temp_item:gsub('[^%w%s#\'-]', ''):gsub('^%s*(.-)%s*$', '%1')
        table.insert(state.temp_items, {name = temp_item, time = get_time_string()})
        
        -- Identify sector from Temp Item (e.g. "Ra'Kaznar shard #A" -> Sector A)
        local sector_match = temp_item:match("#([A-H])")
        if sector_match then
            state.current_sector = sector_match
            if state.sectors[sector_match] then
                state.sectors[sector_match].Ch = state.sectors[sector_match].Ch + 1
            end
        elseif temp_item:lower():find("seal") then
            state.other["G Seal"] = state.other["G Seal"] + 1
        end
    end

    -- Tracking Boss Defeats
    -- Examples: "The party defeats Aminon." or "Player defeats Aminon."
    local defeat_target = cleaned_line:lower():match("defeats?%s+the%s+([^%.]+)%.") or cleaned_line:lower():match("defeats?%s+([^%.]+)%.")
    if defeat_target then
        defeat_target = defeat_target:lower()
        if state.boss_list[defeat_target] then
            local boss_info = state.boss_list[defeat_target]
            -- Check if already recorded to prevent duplicates if chat echoes
            local already_recorded = false
            for _, b in ipairs(state.bosses_killed) do
                if b.name == boss_info.name then already_recorded = true break end
            end
            if not already_recorded then
                state.current_sector = boss_info.sector -- Update context
                table.insert(state.bosses_killed, {
                    name = boss_info.name,
                    time = get_time_string(),
                    type = boss_info.type,
                    sector = boss_info.sector
                })
            end
        end
    end
end)

function tracker.get_state()
    return state
end

function tracker.reset()
    state.run_gallimaufry = 0
    state.bosses_killed = {}
    state.chests_opened = {}
    state.temp_items = {}
    state.cases = { ["Old Case"] = 0, ["Old Case +1"] = 0, ["Old Case +2"] = 0 }
    state.sectors = {
        A = { Ch = 0, Ca = 0, Co = 0 }, B = { Ch = 0, Ca = 0, Co = 0 },
        C = { Ch = 0, Ca = 0, Co = 0 }, D = { Ch = 0, Ca = 0, Co = 0 },
        E = { Ch = 0, Ca = 0, Co = 0 }, F = { Ch = 0, Ca = 0, Co = 0 },
        G = { Ch = 0, Ca = 0, Co = 0 }, H = { Ch = 0, Ca = 0, Co = 0 }
    }
    state.other = { ["Ground Aurum"] = 0, ["Basement Aurum"] = 0, ["G Seal"] = 0 }
    state.current_sector = "A"
end

return tracker
