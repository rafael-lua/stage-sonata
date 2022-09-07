local should = require "modules.should"
local hashes = require "modules.hashes"
local helpers = require "modules.helpers"
local game_grid = {}

-- Possible blocks options per cell.
local cell_blocks = {"red", "blue", "green", "yellow"}

-- Default grid configs.
local defaultGrid = {
    cell_size = 32,
    gap = 0,
    rows = 5,
    cols = 5,
    x = 0,
    y = 0,
    cells = {},
    state = {
        focus = nil, -- Mouse hovering - {row, col}.
        selected = nil, -- Block grabbed - {row, col, block, instance}.
        empty = nil, -- Current empty cell during block grab state - {row, col}.
        highlighted_axis = nil -- Row and col to highlight on grabbed state - {row, col}.
    },
    player_id = hash("")
}

function game_grid.new(gridConfig)
    -- Initialize grid config and overwrites the defaults with the optional gridConfig parameter.
    local grid_props = helpers.deepmerge(helpers.deepcopy(defaultGrid), gridConfig)

    grid_props.cells_total = grid_props.rows * grid_props.cols
    grid_props.height = (grid_props.rows * grid_props.cell_size) + ((grid_props.rows - 1) * grid_props.gap)
    grid_props.width = (grid_props.cols * grid_props.cell_size) + ((grid_props.cols - 1) * grid_props.gap)

    -- Gets a random valid block.
    function grid_props.getRandomBlock()
        local rand_index = math.ceil(math.random() * #cell_blocks)

        return cell_blocks[rand_index]
    end

    -- Convert mouse position to grid coordinates (x and y indexes). Also,
    -- returns if the coordinate is inside the grid.
    function grid_props.getFocusIndex(action, grid_world_pos)
        local isWithinGrid = helpers.coordTouchsRectangle(
            action.x, action.y, grid_world_pos, grid_props.width, grid_props.height
        )

        local action_offset_col_index = math.floor(
            (action.x - grid_world_pos.x) / (grid_props.cell_size + grid_props.gap)
        )
        local action_offset_row_index = math.floor(
            (action.y - grid_world_pos.y) / (grid_props.cell_size + grid_props.gap)
        )

        return action_offset_col_index, action_offset_row_index, isWithinGrid
    end

    -- Utility for looping through all cells, calling the provided function on each.
    function grid_props.forEachCell(fn)
        should.be.fn(fn, "forEachCell:fn")
        assert(
            type(grid_props.cells) == "table" and next(grid_props.cells) ~= nil,
                "grid:cells is empty, did you forgot to initialize the cells?"
        )

        for col = 0, (grid_props.cols - 1) do
            for row = (grid_props.rows - 1), 0, -1 do
                fn(grid_props.cells[col][row])
            end
        end
    end

    -- Get the cell's gap. Gaps are extra spaces to the right or top of cells, except
    -- for the last ones. It adds value to the cell's position to create spacing.
    function grid_props.getGaps(col, row)
        should.be.all.number({col, row}, "getGaps")

        local gapX = (col > 0) and grid_props.gap or 0
        local gapY = (row > 0) and grid_props.gap or 0

        return gapX, gapY
    end

    -- Gets the world position (pixels) given an col and row index on the grid.
    function grid_props.getCellWorldPosition(col, row)
        should.be.all.number({col, row}, "getCellWorldPosition")
        assert(
            col <= grid_props.cols and row <= grid_props.rows,
                "'getCellWorldPosition' col or row parameter were bigger than the grid cells amount:" ..
                    grid_props.cells_total
        )
        assert(col >= 0 and row >= 0, "'getCellWorldPosition' col or row parameter was smaller than 0")

        local gapX, gapY = grid_props.getGaps(col, row)

        local cell_x = col * (grid_props.cell_size + gapX)
        local cell_y = row * (grid_props.cell_size + gapY)

        return vmath.vector3((cell_x + grid_props.x), (cell_y + grid_props.y), 0)
    end

    -- Function to spawn the cells on the grid. Needs an valid cell factory url.
    function grid_props.generateCells(factoryUrl)
        grid_props.cells = {} -- Essentially resets the grid.

        for grid_col = 0, (grid_props.cols - 1) do
            grid_props.cells[grid_col] = {}

            for grid_row = 0, (grid_props.rows - 1), 1 do
                local props = {
                    pos = grid_props.getCellWorldPosition(grid_col, grid_row),
                    index_col = grid_col,
                    index_row = grid_row,
                    size = grid_props.cell_size,
                    animation = "basic",
                    block = grid_props.getRandomBlock()
                }

                local cell_collection = collectionfactory.create(factoryUrl, props.pos)
                local cell_instance = cell_collection[hash("/grid_cell")]
                local cell_block_instance = cell_collection[hash("/block")]

                go.set(msg.url(nil, cell_instance, "logic"), "block", msg.url(nil, cell_block_instance, nil))
                go.set(msg.url(nil, cell_instance, "logic"), "player", grid_props.player_id)
                go.set_parent(cell_instance, go.get_id())
                go.set_parent(cell_block_instance, go.get_id())
                msg.post(
                    cell_instance, "set_block", {
                        block = props.block
                    }
                )
                label.set_text(msg.url(nil, cell_instance, "index"), props.index_col .. "," .. props.index_row)

                grid_props.cells[grid_col][grid_row] = {
                    props = props,
                    collection = cell_collection,
                    instance = cell_instance,
                    block_instance = cell_block_instance
                }
            end
        end
    end

    -- Clear the current focus state if focus is set.
    function grid_props.clearFocus()
        if grid_props.state.focus then
            local focus_state_col = grid_props.state.focus.col
            local focus_state_row = grid_props.state.focus.row
            msg.post(
                grid_props.cells[focus_state_col][focus_state_row].instance, "set_focus", {
                    focus = false
                }
            )

            grid_props.state.focus = nil
        end
    end

    -- Given an focus index, update the current focused cell state.
    -- It will clear previous focused cell and also clear if the focus 
    -- intent is not within the grid.
    function grid_props.updateFocus(focusCol, focusRow, isWithinGrid)
        if not isWithinGrid then
            grid_props.clearFocus()
            return
        end

        -- We only update focus if we need to.
        if grid_props.state.focus ~= nil then
            local focus_state_col = grid_props.state.focus.col
            local focus_state_row = grid_props.state.focus.row

            if focusCol == focus_state_col and focusRow == focus_state_row then
                return
            end
        end

        grid_props.clearFocus()
        msg.post(
            grid_props.cells[focusCol][focusRow].instance, "set_focus", {
                focus = true
            }
        )

        grid_props.state.focus = {
            col = focusCol,
            row = focusRow
        }
    end

    -- Select the block of the current focused grid cell.
    function grid_props.selectBlock(action, selected_block_factory)
        local cellFocus = grid_props.state.focus
        assert(cellFocus ~= nil, "There is no valid focused cell to select.")

        -- We only allow one selected at time. The implementation should solve the current
        -- selected block first before trying to select a new one.
        if not grid_props.state.selected then
            -- We set the current focused cell as the selected.
            grid_props.state.selected = {
                row = cellFocus.row,
                col = cellFocus.col,
                block = grid_props.cells[cellFocus.col][cellFocus.row].props.block
            }

            -- We also set the current empty space reference.
            grid_props.state.empty = {
                row = cellFocus.row,
                col = cellFocus.col
            }

            -- Create the instance to draw the selected block at the cursor position.
            grid_props.state.selected.instance = factory.create(
                selected_block_factory, vmath.vector3(action.x, action.y, 0)
            )

            local selectedBlock = grid_props.state.selected
            -- Stop rendering the grid cell's block and start drawing the selected block.
            msg.post(grid_props.cells[selectedBlock.col][selectedBlock.row].instance, "disable_block")
            msg.post(
                selectedBlock.instance, "play_animation", {
                    id = hashes.cell.animation[selectedBlock.block]
                }
            )

            -- Remove the block from the selected grid cell.
            grid_props.cells[selectedBlock.col][selectedBlock.row].props.block = nil
        end
    end

    -- Move the target cell to the current empty space.
    function grid_props.moveToEmpty(target_cell_to_move)
        local currentEmptyCell = grid_props.state.empty
        local emptyCell = grid_props.cells[currentEmptyCell.col][currentEmptyCell.row]

        -- Move the target block to the available empty space.
        msg.post(
            emptyCell.instance, "place_block", {
                block = target_cell_to_move.props.block,
                from_position = target_cell_to_move.props.pos
            }
        )
        emptyCell.props.block = target_cell_to_move.props.block

        -- Make target cell the new empty cell.
        msg.post(target_cell_to_move.instance, "disable_block")
        target_cell_to_move.props.block = nil
    end

    -- Place the given block to the target grid cell.
    function grid_props.placeBlock(target_cell, block)
        should.be.cellCoordinate(target_cell, "target_cell")
        should.be.block(block, "block")

        local cell = grid_props.cells[target_cell.col][target_cell.row]
        msg.post(
            cell.instance, "place_block", {
                block = block.block
            }
        )
        cell.props.block = block.block
    end

    -- Check if the current focus is a diagonal position in relation to the given target.
    function grid_props.isDiagonal(target)
        should.be.cellCoordinate(target, "target")

        local cellFocus = grid_props.state.focus
        return (target.col ~= cellFocus.col and target.row ~= cellFocus.row)
    end

    -- Based on the current empty cell and current cell focus, 
    -- move blocks in the correct order to open space.
    function grid_props.makeSpace(ignore_diagonal, custom_focus)
        local emptyCell = grid_props.state.empty

        if (emptyCell) then
            local cellFocus = custom_focus ~= nil and custom_focus or grid_props.state.focus
            local selectedBlock = grid_props.state.selected

            local should_ignore_diagonal = ignore_diagonal == nil and true or ignore_diagonal
            -- We ignore diagonals using the grabbed cell position as reference.
            if (should_ignore_diagonal and grid_props.isDiagonal(selectedBlock)) then
                return
            end

            -- We need to figure out an order for the axis to be solved 
            -- when both needs to change (for animation).
            local col_order, row_order, has_order_preference = 0, 0, false
            if (emptyCell.col ~= cellFocus.col and emptyCell.row ~= cellFocus.row) then
                if emptyCell.col ~= selectedBlock.col then
                    col_order = 1
                    row_order = 2
                else
                    row_order = 1
                    col_order = 2
                end

                has_order_preference = true
            end

            -- We need to figure out movement directions for the empty space cell needle.
            local stepCol, stepRow = 0, 0
            if emptyCell.col > cellFocus.col then
                stepCol = -1
            elseif emptyCell.col < cellFocus.col then
                stepCol = 1
            end

            if emptyCell.row > cellFocus.row then
                stepRow = -1
            elseif emptyCell.row < cellFocus.row then
                stepRow = 1
            end

            -- Axis solving functions.
            local function solve_col_axis()
                if stepCol ~= 0 then
                    local needle = emptyCell.col
                    while (needle ~= cellFocus.col) do
                        local target_cell = grid_props.cells[needle + stepCol][emptyCell.row]

                        grid_props.moveToEmpty(target_cell)

                        emptyCell.col = target_cell.props.index_col
                        needle = needle + stepCol
                    end
                end
            end

            local function solve_row_axis()
                if stepRow ~= 0 then
                    local needle = emptyCell.row
                    while (needle ~= cellFocus.row) do
                        local target_cell = grid_props.cells[emptyCell.col][needle + stepRow]

                        grid_props.moveToEmpty(target_cell)

                        emptyCell.row = target_cell.props.index_row
                        needle = needle + stepRow
                    end
                end
            end

            if (has_order_preference) then
                local call_order = {
                    [col_order] = solve_col_axis,
                    [row_order] = solve_row_axis
                }

                call_order[1]()
                call_order[2]()
            else
                solve_col_axis()
                solve_row_axis()
            end
        end
    end

    -- Make the current selected block the empty cell
    -- by forcing it as the current focus.
    function grid_props.resetSpace()
        local customFocus = {
            col = grid_props.state.selected.col,
            row = grid_props.state.selected.row
        }
        grid_props.makeSpace(false, customFocus)
    end

    -- Place the current selected block to the grid.
    function grid_props.placeSelectedBlock()
        local selectedBlock = grid_props.state.selected

        if (selectedBlock) then
            local cellFocus = grid_props.state.focus

            -- The position of the selected block's cell defines the reference for the
            -- diagonal check, since we want to lock movements to only horizontal and vertical 
            -- lines from the selected position.
            if (cellFocus and not grid_props.isDiagonal(selectedBlock)) then
                grid_props.placeBlock(cellFocus, selectedBlock)
                -- Block placed, we have no current empty cells. Important for the matching check.
                grid_props.state.empty = nil
            end

            -- Some invalid movement, like diagonal or outside grid. We place back the selected block
            -- to its original position on the grid.
            if (grid_props.state.empty) then
                grid_props.resetSpace()
                grid_props.placeBlock(selectedBlock, selectedBlock)
                grid_props.state.empty = nil
            end

            -- We clear the current selected block, as well as deleting its instance.
            go.delete(selectedBlock.instance)
            grid_props.state.selected = nil
        end
    end

    -- Set highlight for the selected cell row and col axis.
    function grid_props.setAxisHighlight(highlight)
        local row_axis = grid_props.state.selected.row
        local col_axis = grid_props.state.selected.col
        local cells = grid_props.cells

        for col = 0, grid_props.cols - 1, 1 do
            msg.post(
                cells[col][row_axis].instance, "set_highlight", {
                    highlight = highlight
                }
            )
        end

        for row = 0, grid_props.rows - 1, 1 do
            msg.post(
                cells[col_axis][row].instance, "set_highlight", {
                    highlight = highlight
                }
            )
        end
    end

    function grid_props.highlightAxis(grabbed)
        if (grabbed and grid_props.state.selected) then
            grid_props.setAxisHighlight(true)
        elseif (grid_props.state.selected) then
            grid_props.setAxisHighlight(false)
        end
    end

    return grid_props
end

return game_grid
