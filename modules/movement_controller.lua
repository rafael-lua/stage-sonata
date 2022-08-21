local hashes = require "modules.hashes"
local movement_controller = {}

--[[ 
    NOTE: At this moment, the module will not work properly with diagonals 
]]

local checkBounds = function(direction, index_x, index_y, gridRows, gridCols)
    local validBoundary = {
        x = index_x,
        y = index_y
    }

    if ((direction == "left") and (index_x - 1) >= 0) then
        validBoundary.x = index_x - 1
    elseif ((direction == "right") and (index_x + 1) < gridCols) then
        validBoundary.x = index_x + 1
    elseif ((direction == "bottom") and (index_y - 1) >= 0) then
        validBoundary.y = index_y - 1
    elseif ((direction == "up") and (index_y + 1) < gridRows) then
        validBoundary.y = index_y + 1
    else
        validBoundary = nil
    end

    return validBoundary
end

local canMoveToDirection = function(direction, cell_focus, gridCells, gridRows, gridCols)
    local validBoundary = checkBounds(direction, cell_focus.x, cell_focus.y, gridRows, gridCols)

    if (validBoundary and (gridCells[validBoundary.x][validBoundary.y].props.block == nil)) then
        return validBoundary
    end

    return false
end

function movement_controller.moveToEmpty(target_cell_to_move, empty_cell)
    msg.post(
        empty_cell.instance, "place_block", {
            block = target_cell_to_move.props.block
        }
    ) -- move the target block to the available empty space
    empty_cell.props.block = target_cell_to_move.props.block

    msg.post(target_cell_to_move.instance, "disable_block") -- make the target cell the new empty
    target_cell_to_move.props.block = nil
end

function movement_controller.makeSpace(current_empty_cell, cell_focus, selected_block, grid)
    -- we ignore diagonals using the grabbed cell position reference
    if (selected_block.x ~= cell_focus.x and selected_block.y ~= cell_focus.y) then
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
    local new_empty_cell = {
        x = selected_block.x,
        y = selected_block.y
    }

    local stepX, stepY = 0, 0
    if current_empty_cell.x > selected_block.x then
        stepX = -1
    elseif current_empty_cell.x < selected_block.x then
        stepX = 1
    end

    if current_empty_cell.y > selected_block.y then
        stepY = -1
    elseif current_empty_cell.y < selected_block.y then
        stepY = 1
    end

    if stepX ~= 0 then
        local needle = current_empty_cell.x
        while (needle ~= selected_block.x) do
            local empty_cell = grid.cells[needle][current_empty_cell.y]
            local target_cell = grid.cells[needle + stepX][current_empty_cell.y]

            movement_controller.moveToEmpty(target_cell, empty_cell)

            needle = needle + stepX
        end
    elseif stepY ~= 0 then
        local needle = current_empty_cell.y
        while (needle ~= selected_block.y) do
            local empty_cell = grid.cells[current_empty_cell.x][needle]
            local target_cell = grid.cells[current_empty_cell.x][needle + stepY]

            movement_controller.moveToEmpty(target_cell, empty_cell)

            needle = needle + stepY
        end
    end

    return new_empty_cell
end

function movement_controller.updateMovement(lastValidMovementIndex, selected_block, cell_focus, grid)
    local gridCells = grid.cells

    if selected_block.x ~= cell_focus.x and selected_block.y ~= cell_focus.y then
        return lastValidMovementIndex
    end

    -- check if there is a valid space to move
    local leftSpace = canMoveToDirection("left", cell_focus, grid.cells, grid.rows, grid.cols)
    local rightSpace = canMoveToDirection("right", cell_focus, grid.cells, grid.rows, grid.cols)
    local downSpace = canMoveToDirection("bottom", cell_focus, grid.cells, grid.rows, grid.cols)
    local upSpace = canMoveToDirection("up", cell_focus, grid.cells, grid.rows, grid.cols)

    local emptyCell
    if leftSpace then
        emptyCell = grid.cells[leftSpace.x][leftSpace.y]
    elseif rightSpace then
        emptyCell = grid.cells[rightSpace.x][rightSpace.y]
    elseif downSpace then
        emptyCell = grid.cells[downSpace.x][downSpace.y]
    elseif upSpace then
        emptyCell = grid.cells[upSpace.x][upSpace.y]
    end

    if emptyCell then
        local cellToMove = grid.cells[cell_focus.x][cell_focus.y]
        movement_controller.moveToEmpty(cellToMove, emptyCell)
        lastValidMovementIndex = {
            x = cell_focus.x,
            y = cell_focus.y
        }
    end

    return lastValidMovementIndex
end

-- if the move is not valid, reset the grid blocks
function movement_controller.killMovement(lastValidMovementIndex, selected_block, grid)
    local stepX, stepY = 0, 0
    if lastValidMovementIndex.x > selected_block.x then
        stepX = 1
    elseif lastValidMovementIndex.x < selected_block.x then
        stepX = -1
    end

    if lastValidMovementIndex.y > selected_block.y then
        stepY = 1
    elseif lastValidMovementIndex.y < selected_block.y then
        stepY = -1
    end

    if stepX ~= 0 then
        local needle = lastValidMovementIndex.x
        while (needle ~= selected_block.x) do
            local empty_cell = grid.cells[needle][lastValidMovementIndex.y]
            local target_cell = grid.cells[needle - stepX][lastValidMovementIndex.y]

            movement_controller.moveToEmpty(target_cell, empty_cell)

            needle = needle - stepX
        end
    end

    if stepY ~= 0 then
        local needle = lastValidMovementIndex.y
        while (needle ~= selected_block.y) do
            local empty_cell = grid.cells[lastValidMovementIndex.x][needle]
            local target_cell = grid.cells[lastValidMovementIndex.x][needle - stepY]

            movement_controller.moveToEmpty(target_cell, empty_cell)

            needle = needle - stepY
        end
    end

    return nil
end

return movement_controller
