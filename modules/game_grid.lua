local should = require "modules.should"
local hashes = require "modules.hashes"
local helpers = require "modules.helpers"
local debugger = require "modules.debugger"
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
    player_id = hash(""),
    match_factor = 3, -- The minimum amount necessary for a valid match.
    matchless_retries = 1000
}

function game_grid.new(gridConfig)
    -- Initialize grid config and overwrites the defaults with the optional gridConfig parameter.
    local grid_props = helpers.deepmerge(helpers.deepcopy(defaultGrid), gridConfig)

    grid_props.cells_total = grid_props.rows * grid_props.cols
    grid_props.height = (grid_props.rows * grid_props.cell_size) + ((grid_props.rows - 1) * grid_props.gap)
    grid_props.width = (grid_props.cols * grid_props.cell_size) + ((grid_props.cols - 1) * grid_props.gap)

    -- Gets a random valid block.
    function grid_props.getRandomBlock()
        local rand_index = math.floor(math.random() * #cell_blocks) + 1

        return cell_blocks[rand_index]
    end

    -- Get a block that will not match, for generating matchless tables.
    -- Block is nil if all blocks match.
    function grid_props.getNextBlock(col, row)
        -- Create a copy of valid blocks
        local block_list = {}

        for _, cellBlock in pairs(cell_blocks) do
            table.insert(
                block_list, {
                    value = cellBlock,
                    sort_factor = math.random()
                }
            )
        end

        -- Sort it randomly
        table.sort(
            block_list, function(a, b)
                return a.sort_factor > b.sort_factor
            end
        )

        -- Pop until a valid block is found or throws if none is valid.
        local random_block = table.remove(block_list)

        -- Keep trying new blocks until one without a match is found.
        while grid_props.block_matches_behind(col, row, random_block.value) do
            if #block_list > 0 then
                random_block = table.remove(block_list)
            else
                random_block.value = nil
                break
            end
        end

        return random_block.value
    end

    -- Simple match check that only takes in consideration previous blocks and stops at 3.
    function grid_props.block_matches_behind(col, row, block)
        local matched = false

        if col >= 2  then
            local col_match_count = 0

            for col_index = col - 1, col - (grid_props.match_factor - 1), -1 do
                if (grid_props.cells[col_index][row].props.block == block) then
                    col_match_count = col_match_count + 1
                end
            end

            if col_match_count >= (grid_props.match_factor - 1) then
                matched = true
            end
        end

        if row >= 2 then
            local row_match_count = 0

            for row_index = row - 1, row - (grid_props.match_factor - 1), -1 do
                if (grid_props.cells[col][row_index].props.block == block) then
                    row_match_count = row_match_count + 1
                end
            end

            if row_match_count >= (grid_props.match_factor - 1) then
                matched = true
            end
        end

        return matched
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
            for row = 0, (grid_props.rows - 1), 1 do
                if grid_props.cells[col] then
                    fn(grid_props.cells[col][row])
                end
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
    -- It counts blocks and make sure the grid initialize without matches.
    function grid_props.generateCells(factoryUrl)
        local retries = grid_props.matchless_retries
        local generated = false

        while (not generated and retries > 0) do
            grid_props.cells = {}
            local valid_grid = true

            for grid_col = 0, (grid_props.cols - 1) do
                grid_props.cells[grid_col] = {}

                for grid_row = 0, (grid_props.rows - 1), 1 do
                    local props = {
                        pos = grid_props.getCellWorldPosition(grid_col, grid_row),
                        index_col = grid_col,
                        index_row = grid_row,
                        size = grid_props.cell_size,
                        animation = "basic",
                        block = grid_props.getNextBlock(grid_col, grid_row),
                        cluster = nil -- Used to check clusters overlap on matches.
                    }

                    if props.block == nil then
                        valid_grid = false
                        break
                    end

                    grid_props.cells[grid_col][grid_row] = {
                        props = props
                    }
                end

                if not valid_grid then
                    break
                end
            end

            retries = retries - 1
            generated = valid_grid
        end

        assert(
            retries > 0,
                "Retries limit reached for generating matchless grid. Make sure there is enough block variants."
        )

        grid_props.forEachCell(
            function(cell)
                local cell_collection = collectionfactory.create(factoryUrl, cell.props.pos)
                local cell_instance = cell_collection[hash("/grid_cell")]
                local cell_block_instance = cell_collection[hash("/block")]

                go.set(msg.url(nil, cell_instance, "logic"), "block", msg.url(nil, cell_block_instance, nil))
                go.set(msg.url(nil, cell_instance, "logic"), "player", grid_props.player_id)
                go.set_parent(cell_instance, go.get_id())
                go.set_parent(cell_block_instance, go.get_id())
                msg.post(
                    cell_instance, "set_block", {
                        block = cell.props.block
                    }
                )
                label.set_text(msg.url(nil, cell_instance, "index"), cell.props.index_col .. "," .. cell.props.index_row)

                cell.collection = cell_collection
                cell.instance = cell_instance
                cell.block_instance = cell_block_instance
            end
        )
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

    -- Update the axis highlight based on grabbed status and selected position.
    function grid_props.highlightAxis(grabbed)
        if (grabbed and grid_props.state.selected) then
            grid_props.setAxisHighlight(true)
        elseif (grid_props.state.selected) then
            grid_props.setAxisHighlight(false)
        end
    end

    -- Run on the grid and check if there is match, clearing the blocks.
    function grid_props.checkMatches()
        local cells = grid_props.cells
        -- Matches contains an array of matched blocks divided into clusters.
        -- Each item has the match amount, the block type and the array of indexes.
        local matches = {}
        local cluster_index = 1

        -- Solve col clusters.
        for row = 0, grid_props.rows - 1, 1 do
            local col = 0 -- We want the possibility of modifying the loop variable.
            while (col <= grid_props.cols - (grid_props.match_factor - 1)) do
                local base_cell = cells[col][row]
                -- We start the clutch with the base_cell.
                local cluster = {
                    count = 0,
                    block = base_cell.props.block,
                    matched = {}
                }

                local needle = col
                -- Check cell from the base one as long the block matches.
                while (needle < grid_props.cols and cells[needle][row].props.block == base_cell.props.block) do
                    cluster.count = cluster.count + 1
                    table.insert(
                        cluster.matched, {
                            row = row,
                            col = needle
                        }
                    )
                    needle = needle + 1
                end

                -- There is match for the base_cell in this direction
                if cluster.count >= 3 then
                    matches[cluster_index] = cluster

                    for _, matched_cell in pairs(cluster.matched) do
                        cells[matched_cell.col][matched_cell.row].props.cluster = cluster_index
                    end

                    col = col + cluster.count -- We can push the loop to the counter index and avoid unecessary checks.
                    cluster_index = cluster_index + 1 -- We only increase the cluster index if necessary.
                else
                    col = col + 1
                end
            end
        end

        -- Solve row clusters.
        for col = 0, grid_props.cols - 1, 1 do
            local row = 0 -- We want the possibility of modifying the loop variable.
            while (row <= grid_props.rows - (grid_props.match_factor - 1)) do
                local base_cell = cells[col][row]
                -- We start the clutch with the base_cell.
                local cluster = {
                    count = 0,
                    block = base_cell.props.block,
                    matched = {}
                }

                -- We do that to check if cols/rows clusters overlap to form a bigger cluster.
                local should_merge_clusters = {
                    overlaped_clusters = {}, -- List of clusters indexes that will be merged.
                    has_overlaps = false
                }

                local needle = row
                -- Check cell from the base one as long the block matches.
                while (needle < grid_props.rows and cells[col][needle].props.block == base_cell.props.block) do
                    local cell_cluster = cells[col][needle].props.cluster
                    if (cell_cluster) then
                        should_merge_clusters.has_overlaps = true
                        should_merge_clusters.overlaped_clusters[cell_cluster] = cell_cluster
                    end

                    cluster.count = cluster.count + 1
                    table.insert(
                        cluster.matched, {
                            row = needle,
                            col = col
                        }
                    )
                    needle = needle + 1
                end

                -- There is match for the base_cell in this direction
                if cluster.count >= 3 then
                    matches[cluster_index] = cluster

                    -- Check if we need to merge clusters
                    if should_merge_clusters.has_overlaps then
                        -- Loop on the clusters indexes that should be merged.
                        for _, overlaped_cluster_index in pairs(should_merge_clusters.overlaped_clusters) do
                            -- Loop on the overlapped cluster cells, merge to the new cluster.
                            for _, cell_to_merge in pairs(matches[overlaped_cluster_index].matched) do
                                -- We only merge cells that aren't part of the cluster already, avoiding duplicates.
                                local unique = true
                                for _, cluster_cell in pairs(matches[cluster_index].matched) do
                                    if (cluster_cell.row == cell_to_merge.row and cluster_cell.col == cell_to_merge.col) then
                                        unique = false
                                    end
                                end

                                if unique then
                                    table.insert(matches[cluster_index].matched, cell_to_merge)
                                end
                            end

                            -- Remove overlaped cluster.
                            matches[overlaped_cluster_index] = nil
                        end
                    end

                    for _, matched_cell in pairs(matches[cluster_index].matched) do
                        cells[matched_cell.col][matched_cell.row].props.cluster = cluster_index
                    end

                    row = row + cluster.count -- We can push the loop to the counter index and avoid unecessary checks.
                    cluster_index = cluster_index + 1 -- We only increase the cluster index if necessary.
                else
                    row = row + 1
                end
            end
        end

        -- debug
        debugger.setMessage("clusters", "Amount of clusters: " .. helpers.count(matches))

        grid_props.forEachCell(
            function(cell)
                msg.post(
                    cell.instance, "set_match", {
                        matched = false
                    }
                )
            end
        )

        for _, v in pairs(matches) do
            for _, cell in pairs(v.matched) do
                msg.post(
                    cells[cell.col][cell.row].instance, "set_match", {
                        matched = true
                    }
                )
            end
        end

        grid_props.forEachCell(
            function(cell)
                cell.props.cluster = nil
            end
        )
    end

    return grid_props
end

return game_grid
