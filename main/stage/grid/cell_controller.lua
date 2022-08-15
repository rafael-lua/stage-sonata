-- helper scripts to deal with grid cells
local cell_controller = {}
local math = math
local collider = require "modules.collider"

function cell_controller.updateTouch(cell, action)
    local isTouching = collider.coordTouchsCell(action.x, action.y, go.get_world_position(cell.instance),
        cell.props.size)

    if isTouching and cell.animation ~= "basic_2" then
        cell.animation = "basic_2"
        msg.post(msg.url(nil, cell.instance, "cell_frame"), "play_animation", {
            id = hash("basic_2")
        })
    elseif not isTouching and cell.animation ~= "basic" then
        cell.animation = "basic"
        msg.post(msg.url(nil, cell.instance, "cell_frame"), "play_animation", {
            id = hash("basic")
        })
    end
end

return cell_controller
