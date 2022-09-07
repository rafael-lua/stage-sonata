local hashes = {}

hashes.debug = {
    toggle_debug = hash("toggle_debug")
}

hashes.game_state = {
    state_synced = hash("state_synced"),
    sync_state = hash("sync_state")
}

hashes.input = {
    touch = hash("touch")
}

hashes.cell = {
    set_block = hash("set_block"),
    set_focus = hash("set_focus"),
    set_match = hash("set_match"),
    set_highlight = hash("set_highlight"),
    disable_block = hash("disable_block"),
    place_block = hash("place_block"),
    animation = {
        basic = hash("basic"),
        basic_h = hash("basic_h"),
        basic_2 = hash("basic_2"),
        basic_match = hash("basic_match"),
        red = hash("red"),
        green = hash("green"),
        blue = hash("blue"),
        yellow = hash("yellow")
    }
}

return hashes
