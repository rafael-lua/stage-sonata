local hashes = require "modules.hashes"
local cell_controller = {}

function cell_controller.updateFocus(cell_focus, grid_cells, x_index, y_index)
    if cell_focus then
        cell_controller.resetFocus(cell_focus, grid_cells)
    end

    msg.post(grid_cells[x_index][y_index].instance, "set_focus", {
        focus = true
    })

    return {
        x = x_index,
        y = y_index
    }
end

function cell_controller.resetFocus(last, grid_cells)
    msg.post(grid_cells[last.x][last.y].instance, "set_focus", {
        focus = false
    })

    return nil
end

function cell_controller.selectBlock(grid_cells, action, x_index, y_index)
    local selected_block = {
        x = x_index,
        y = y_index,
        block = grid_cells[x_index][y_index].props.block
    }

    selected_block.instance = factory.create("#block_selected", vmath.vector3(action.x, action.y, 0))

    msg.post(grid_cells[selected_block.x][selected_block.y].instance, "select_block")
    msg.post(selected_block.instance, "play_animation", {
        id = hashes.cell.animation[selected_block.block]
    })

    return selected_block
end

function cell_controller.placeBlock(grid_cells, selected_block)
    msg.post(grid_cells[selected_block.x][selected_block.y].instance, "place_block", {
        block = selected_block.block
    })
    go.delete(selected_block.instance)

    return nil
end

return cell_controller
