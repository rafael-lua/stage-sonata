-- helper scripts to deal with grid cells
local cell_controller = {}
local math = math
local collider = require "modules.collider"
local hashes = require "modules.hashes"

local cell_blocks = {"red", "blue", "green", "yellow"}

function cell_controller.getRandomBlock()
    local rand_index = math.ceil(math.random() * #cell_blocks)

    return cell_blocks[rand_index]
end

function cell_controller.updateTouch(cell, action)
    local isTouching = collider.coordTouchsCell(action.x, action.y, go.get_world_position(cell.instance),
        cell.props.size)

    if isTouching and cell.animation ~= "basic_2" then
        cell.animation = "basic_2"
        msg.post(msg.url(nil, cell.instance, "cell_frame"), "play_animation", {
            id = hashes.cell.animation.basic_2
        })
    elseif not isTouching and cell.animation ~= "basic" then
        cell.animation = "basic"
        msg.post(msg.url(nil, cell.instance, "cell_frame"), "play_animation", {
            id = hashes.cell.animation.basic
        })
    end
end

function cell_controller.setBlock(cell)
    msg.post(msg.url(nil, cell.instance, "block"), "play_animation", {
        id = hashes.cell.animation[cell.props.block]
    })
end

return cell_controller
