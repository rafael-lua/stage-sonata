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
    animation = {
        basic = hash("basic"),
        basic_2 = hash("basic_2"),
        red = hash("red"),
        green = hash("green"),
        blue = hash("blue"),
        yellow = hash("yellow")
    }
}

return hashes
