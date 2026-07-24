local parser = {}

local packets = require('packets')
local res = require('resources')

local party_jobs = {}

windower.register_event('incoming chunk', function(id, data)
    if id == 0x0DD then
        local packet = packets.parse('incoming', data)
        if packet then
            local name = packet['Name']
            local main_job = packet['Main job']
            local sub_job = packet['Sub job']
            
            if name and name ~= '' and main_job and sub_job then
                party_jobs[name] = {
                    main = res.jobs[main_job] and res.jobs[main_job].en_short or "UNK",
                    sub = res.jobs[sub_job] and res.jobs[sub_job].en_short or "UNK"
                }
            end
        end
    end
end)

-- Store total damage per player
local damage_data = {
    total = 0,
    players = {} -- [player_name] = damage
}

local offense_action_messages = {
	[1] = 'melee',
	[67] = 'crit',
	[352] = 'ranged', [576] = 'ranged', [577] = 'ranged',
	[353] = 'r_crit',
	[185] = 'ws', [197] = 'ws', [187] = 'ws',
	[2] = 'spell', [227] = 'spell',
	[252] = 'mb', [265] = 'mb', [274] = 'mb', [379] = 'mb', [747] = 'mb', [748] = 'mb',
	[110] = 'ja', [317] = 'ja', [522] = 'ja', [802] = 'ja',
	[157] = 'Barrage',
	[77] = 'Sange',
	[264] = 'aoe'
}

local hit_messages = {
    [1]=true, [67]=true, [352]=true, [576]=true, [577]=true, [353]=true, [185]=true, [197]=true, [187]=true
}

local ws_messages = {
    [185]=true, [197]=true, [187]=true
}

local miss_messages = {
    [15]=true, [63]=true, [354]=true, [188]=true
}

local add_effect_messages = {
    [161] = true, [163] = true, [229] = true,
    [288]=true, [289]=true, [290]=true, [291]=true, [292]=true, [293]=true, [294]=true, [295]=true,
    [296]=true, [297]=true, [298]=true, [299]=true, [300]=true, [301]=true, [302]=true, [385]=true,
    [386]=true, [387]=true, [388]=true, [389]=true, [390]=true, [391]=true, [392]=true, [393]=true,
    [394]=true, [395]=true, [396]=true, [397]=true, [398]=true, [732]=true, [767]=true, [768]=true,
    [769]=true, [770]=true
}

local skillchain_messages = {
    [288]=true, [289]=true, [290]=true, [291]=true, [292]=true, [293]=true, [294]=true, [295]=true,
    [296]=true, [297]=true, [298]=true, [299]=true, [300]=true, [301]=true, [302]=true, [385]=true,
    [386]=true, [387]=true, [388]=true, [389]=true, [390]=true, [391]=true, [392]=true, [393]=true,
    [394]=true, [395]=true, [396]=true, [397]=true, [398]=true, [732]=true, [767]=true, [768]=true,
    [769]=true, [770]=true
}

local add_effect_valid = {
    [1] = true, [2] = true, [3] = true, [4] = true, [11] = true, [13] = true
}

local function get_player_info(id)
    local mob = windower.ffxi.get_mob_by_id(id)
    if not mob then return nil end
    
    local is_party_or_alliance = false
    local is_pet = false
    local owner_name = nil

    if mob.is_npc then
        -- Check if pet
        for i, v in pairs(windower.ffxi.get_party()) do
            if type(v) == 'table' and v.mob and v.mob.pet_index == mob.index then
                is_pet = true
                owner_name = v.name
                break
            end
        end
    else
        -- Check if party or alliance
        for i, v in pairs(windower.ffxi.get_party()) do
            if type(v) == 'table' and v.mob and v.mob.id == mob.id then
                is_party_or_alliance = true
                break
            end
        end
    end

    return {
        name = mob.name,
        is_party = is_party_or_alliance,
        is_pet = is_pet,
        owner = owner_name,
        type = mob.is_npc and (is_pet and "pet" or "mob") or "pc"
    }
end

local function record_damage(player_name, damage, is_ws, is_sc)
    if not damage_data.players[player_name] then
        damage_data.players[player_name] = { damage = 0, hits = 0, misses = 0, ws_damage = 0, ws_count = 0, sc_damage = 0 }
    end
    if damage > 0 then
        damage_data.players[player_name].damage = damage_data.players[player_name].damage + damage
        damage_data.total = damage_data.total + damage
        
        if is_ws then
            damage_data.players[player_name].ws_damage = damage_data.players[player_name].ws_damage + damage
            damage_data.players[player_name].ws_count = damage_data.players[player_name].ws_count + 1
        end
        if is_sc then
            damage_data.players[player_name].sc_damage = damage_data.players[player_name].sc_damage + damage
        end
    end
end

local function record_accuracy(player_name, is_hit)
    if not damage_data.players[player_name] then
        damage_data.players[player_name] = { damage = 0, hits = 0, misses = 0, ws_damage = 0, ws_count = 0 }
    end
    if is_hit then
        damage_data.players[player_name].hits = damage_data.players[player_name].hits + 1
    else
        damage_data.players[player_name].misses = damage_data.players[player_name].misses + 1
    end
end

windower.register_event('action', function(act)
    local actor = get_player_info(act.actor_id)
    if not actor then return end
    
    -- We only care about damage dealt BY party members or their pets
    if not actor.is_party and not actor.is_pet then return end

    local display_name = actor.is_pet and (actor.name .. " (" .. actor.owner .. ")") or actor.name

    for _, targ in pairs(act.targets) do
        local target_info = get_player_info(targ.id)
        if target_info and target_info.type == "mob" then
            for _, m in pairs(targ.actions) do
                if m.message ~= 0 then
                    local action = offense_action_messages[m.message]
                    if action then
                        local is_ws = ws_messages[m.message] or false
                        record_damage(display_name, m.param, is_ws)
                    end

                    if hit_messages[m.message] then
                        record_accuracy(display_name, true)
                    elseif miss_messages[m.message] then
                        record_accuracy(display_name, false)
                    end
                    
                    if m.has_add_effect and add_effect_messages[m.add_effect_message] and add_effect_valid[act.category] then
                        local is_sc = skillchain_messages[m.add_effect_message] or false
                        record_damage(display_name, m.add_effect_param, false, is_sc)
                    end
                end
            end
        end
    end
end)

function parser.get_damage_data()
    local p = windower.ffxi.get_player()
    if p and p.name and p.main_job_id and p.sub_job_id then
        party_jobs[p.name] = {
            main = res.jobs[p.main_job_id] and res.jobs[p.main_job_id].en_short or "UNK",
            sub = res.jobs[p.sub_job_id] and res.jobs[p.sub_job_id].en_short or "UNK"
        }
    end
    damage_data.jobs = party_jobs
    return damage_data
end

function parser.reset()
    damage_data = {
        total = 0,
        players = {}
    }
    party_jobs = {}
end

return parser
