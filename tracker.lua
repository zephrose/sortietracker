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
    chest_list = {}
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
    -- Tracking Gallimaufry
    local player_name, amount = cleaned_line:match("([%a%-']+)%s+received%s+(%d+)%s+gallimaufry%s+for%s+a%s+total%s+of%s+%d+%.*")
    if player_name and amount then
        state.run_gallimaufry = state.run_gallimaufry + tonumber(amount)
        
        -- Chests that give specific amounts can be mapped to chest names
        -- This mimics MuffinMan's detection for chests
        if tonumber(amount) == 1000 then
            table.insert(state.chests_opened, {name = "Aurum Chest", time = get_time_string()})
        elseif tonumber(amount) == 1500 then
            table.insert(state.chests_opened, {name = "Naakual Chest", time = get_time_string()})
        end
    end

    -- Tracking Old Cases
    if cleaned_line:lower():find("obtained:.*old case") then
        local case_name = cleaned_line:match("obtained:.*(Old Case[^%.]*)")
        if case_name then
            table.insert(state.chests_opened, {name = case_name, time = get_time_string()})
        else
            table.insert(state.chests_opened, {name = "Old Case", time = get_time_string()})
        end
    end

    -- Tracking Temporary Items
    local temp_item = cleaned_line:match("temporary item:%s+([^%.]+)%.?")
    if temp_item then
        -- Clean trailing whitespace if any
        temp_item = temp_item:match("^%s*(.-)%s*$")
        table.insert(state.temp_items, {name = temp_item, time = get_time_string()})
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
end

return tracker
