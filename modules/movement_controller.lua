local GAME_STATE = require "modules.game_state"
local hashes = require "modules.hashes"
local movement_controller = {}

--[[ 
    NOTE: At this moment, the module will not work for diagonals
]]

function movement_controller.moveToEmpty(target_cell_to_move, empty_cell)
    GAME_STATE:pushToPlayerProp("is_moving")

    msg.post(
        empty_cell.instance, "place_block", {
            block = target_cell_to_move.props.block,
            from_position = target_cell_to_move.props.pos
        }
    ) -- move the target block to the available empty space
    empty_cell.props.block = target_cell_to_move.props.block

    msg.post(target_cell_to_move.instance, "disable_block") -- make the target cell the new empty
    target_cell_to_move.props.block = nil
end

function movement_controller.isDiagonal(origin_reference, focus)
    return (origin_reference.x ~= focus.x and origin_reference.y ~= focus.y)
end

function movement_controller.makeSpace(current_empty_cell,
    cell_focus,
    selected_block,
    grid,
    ignore_diagonal)
    local should_ignore_diagonal = ignore_diagonal == nil and true or ignore_diagonal
    -- we ignore diagonals using the grabbed cell position reference
    if (should_ignore_diagonal and movement_controller.isDiagonal(selected_block, cell_focus)) then
        return current_empty_cell
    end

    -- we need to figure out an order for the axis to solve when both needs to change (for animation)
    local x_order, y_order, has_order_preference = 0, 0, false
    if (current_empty_cell.x ~= cell_focus.x and current_empty_cell.y ~= cell_focus.y) then
        if current_empty_cell.x ~= selected_block.x then
            x_order = 1
            y_order = 2
        else
            y_order = 1
            x_order = 2
        end

        has_order_preference = true
    end

    local new_empty_cell = {
        x = current_empty_cell.x,
        y = current_empty_cell.y
    }

    local stepX, stepY = 0, 0
    if current_empty_cell.x > cell_focus.x then
        stepX = -1
    elseif current_empty_cell.x < cell_focus.x then
        stepX = 1
    end

    if current_empty_cell.y > cell_focus.y then
        stepY = -1
    elseif current_empty_cell.y < cell_focus.y then
        stepY = 1
    end

    local function solve_x_axis()
        if stepX ~= 0 then
            local needle = new_empty_cell.x
            while (needle ~= cell_focus.x) do
                local empty_cell = grid.cells[needle][new_empty_cell.y]
                local target_cell = grid.cells[needle + stepX][new_empty_cell.y]

                movement_controller.moveToEmpty(target_cell, empty_cell)

                new_empty_cell.x = target_cell.props.index_x
                needle = needle + stepX
            end
        end
    end

    local function solve_y_axis()
        if stepY ~= 0 then
            local needle = new_empty_cell.y
            while (needle ~= cell_focus.y) do
                local empty_cell = grid.cells[new_empty_cell.x][needle]
                local target_cell = grid.cells[new_empty_cell.x][needle + stepY]

                movement_controller.moveToEmpty(target_cell, empty_cell)

                new_empty_cell.y = target_cell.props.index_y
                needle = needle + stepY
            end
        end
    end

    if has_order_preference then
        local call_order = {
            [x_order] = solve_x_axis,
            [y_order] = solve_y_axis
        }

        call_order[1]()
        call_order[2]()
    else
        solve_x_axis()
        solve_y_axis()
    end

    return new_empty_cell
end

function movement_controller.resetSpace(current_empty_cell, selected_block, grid)
    movement_controller.makeSpace(current_empty_cell, selected_block, selected_block, grid, false)

    return nil
end

return movement_controller
