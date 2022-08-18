local math = math
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

return cell_controller
