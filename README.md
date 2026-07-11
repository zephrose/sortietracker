# SortieTracker

**SortieTracker** is a standalone Windower 4 addon for Final Fantasy XI designed to track everything you need during a Sortie run. It seamlessly integrates the currency tracking capabilities of standard Gallimaufry trackers with the comprehensive performance tracking of damage parsers—all without requiring any external dependencies!

## Features

*   **Gallimaufry Tracking**: Automatically tracks and reports your total Gallimaufry earned during the session.
*   **Progression Tracking**: Automatically logs boss kills, opened chests, and temporary items obtained.
*   **Performance Parsing**: Tracks real-time damage dealt, hit accuracy, and weaponskill averages across all party members.
*   **Beautiful UI**: Tabulated and color-coded on-screen display showing Progression and Performance stats.
*   **Discord Webhooks**: Easily report your performance directly to a Discord webhook.
*   **File Exports**: Automatically saves `.txt` reports of your Sortie runs.

## Installation

1. Download or clone this repository.
2. Place the `SortieTracker` folder into your `Windower4/addons/` directory.
3. In game, type `//lua load SortieTracker`.
4. (Optional) Configure your Discord webhook settings inside `report.lua` if you wish to use the `//st discord` command.

## Commands

Use `//sortietracker` or `//st` followed by a command:

*   `//st show` - Show the on-screen display.
*   `//st hide` - Hide the on-screen display.
*   `//st report` - Generate a text file report of the current Sortie run.
*   `//st discord` - Send the text report to your configured Discord webhook.
*   `//st addnote <note>` - Add a custom note to your report.
*   `//st reset` - Reset all tracked data (automatically resets upon entering Sortie).

## Developer Notes

This addon intercepts incoming chat packets and action packets (0x28) to parse combat logs seamlessly in the background without relying on external addons like Scoreboard or Parse.
