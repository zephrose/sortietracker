_addon.name = 'SortieTracker'
_addon.author = 'gnovi'
_addon.version = '1.0'
_addon.command = 'sortietracker'
_addon.commands = {'sortietracker', 'st'}

require('chat')
require('logger')

local currency = require('currency')
local tracker = require('tracker')
local parser = require('parser')
local display = require('display')
local report = require('report')

-- Report settings
local push_to_discord = false
local additional_note = "Nothing to add"

-- Initialize state and displays
tracker.init()
display.init()

-- Main update loop for the UI
local is_running = true
local update_loop = function()
    while is_running do
        display.update()
        coroutine.sleep(1) -- Update once per second
    end
end
coroutine.schedule(update_loop, 1)

local function print_help()
    windower.add_to_chat(207, '[SortieTracker] Commands:')
    windower.add_to_chat(207, '//st show     - Show displays')
    windower.add_to_chat(207, '//st hide       - Hide displays')
    windower.add_to_chat(207, '//st reset      - Reset parse and state')
    windower.add_to_chat(207, '//st resetparse - Reset just the Sortie Performance parse')
    windower.add_to_chat(207, '//st report     - Save full report to file')
    windower.add_to_chat(207, '//st discord    - Toggle Discord webhook pushes')
    windower.add_to_chat(207, '//st addnote    - Add a note to the end of the report')
end

windower.register_event('addon command', function(...)
    local args = {...}
    if #args == 0 then
        print_help()
        return
    end

    local cmd = args[1]:lower()

    if cmd == 'reset' then
        tracker.reset()
        parser.reset()
        currency.request_update()
        additional_note = "Nothing to add"
        windower.add_to_chat(207, '[SortieTracker] Data reset.')
    elseif cmd == 'resetparse' then
        parser.reset()
        windower.add_to_chat(207, '[SortieTracker] Parse data reset.')
    elseif cmd == 'show' then
        display.show()
    elseif cmd == 'hide' then
        display.hide()
    elseif cmd == 'report' then
        windower.add_to_chat(207, '[SortieTracker] Generating full report...')
        report.generate(additional_note, push_to_discord)
    elseif cmd == 'discord' then
        push_to_discord = not push_to_discord
        windower.add_to_chat(207, '[SortieTracker] Discord pushes: ' .. tostring(push_to_discord))
    elseif cmd == 'addnote' then
        if #args > 1 then
            additional_note = table.concat(args, " ", 2)
            windower.add_to_chat(207, "[SortieTracker] Added note: " .. additional_note)
        else
            windower.add_to_chat(123, "[SortieTracker] Please provide a note to add.")
        end
    elseif cmd == 'help' then
        print_help()
    else
        windower.add_to_chat(123, '[SortieTracker] Unknown command.')
        print_help()
    end
end)

windower.register_event('load', function()
    windower.send_command('alias st sortietracker')
end)

windower.register_event('unload', function()
    windower.send_command('unalias st')
    is_running = false
end)
