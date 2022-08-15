local should = require "modules.should"
local cell_controller = require "main.stage.grid.cell_controller"
local game_grid = {}

function game_grid.generate(cellSize, gap, rows, cols, x, y, xOffset, yOffset)
    local newGrid = {
        cell_size = cellSize or 32,
        gap = gap or 0,
        rows = rows or 5,
        cols = cols or 5,
        x = x or 0,
        y = y or 0,
        x_offset = xOffset or 16,
        y_offset = yOffset or 16,
        cells = {}
    }

    newGrid.cells_total = newGrid.rows * newGrid.cols
    newGrid.height = (newGrid.rows * newGrid.cell_size) + ((newGrid.rows - 1) * newGrid.gap)
    newGrid.width = (newGrid.cols * newGrid.cell_size) + ((newGrid.cols - 1) * newGrid.gap)
    newGrid.x = newGrid.x + newGrid.x_offset
    newGrid.y = newGrid.y + newGrid.y_offset

    function newGrid:forEachCell(fn)
        should.be.fn(fn, "forEachCell:fn")
        assert(type(self.cells) == "table" and next(self.cells) ~= nil,
            "grid:cells is empty, did you forgot to initialize ther cells?")

        for col = 0, (self.cols - 1) do
            for row = (self.rows - 1), 0, -1 do
                fn(self.cells[col][row])
            end
        end
    end

    function newGrid:getGaps(x, y)
        should.be.all.number({x, y}, "getGaps")

        local gapX = (x > 0) and self.gap or 0
        local gapY = (y > 0) and self.gap or 0

        return gapX, gapY
    end

    function newGrid:getCellPosition(x, y)
        should.be.all.number({x, y}, "getCellPosition")
        assert(x <= self.cols and y <= self.rows,
            "'getCellPosition' x or y parameter were bigger than the grid cells amount:" .. self.cells_total)
        assert(x >= 0 and y >= 0, "'getCellPosition' x or y parameter was smaller than 0")

        local gapX, gapY = self:getGaps(x, y)

        local cell_x = x * (self.cell_size + gapX)
        local cell_y = y * (self.cell_size + gapY)

        return vmath.vector3((cell_x + self.x), (cell_y + self.y), 0)
    end

    function newGrid:generateCells()
        self.cells = {} -- essentially resets the grid

        -- we count x from 0 and y from the last row (top down)
        for grid_x = 0, (self.cols - 1) do
            self.cells[grid_x] = {}

            for grid_y = (self.rows - 1), 0, -1 do
                self.cells[grid_x][grid_y] = {
                    props = {
                        pos = self:getCellPosition(grid_x, grid_y),
                        index_x = grid_x,
                        index_y = grid_y,
                        size = self.cell_size,
                        animation = "basic",
                        block = cell_controller.getRandomBlock()
                    }
                }
            end
        end
    end

    return newGrid
end

return game_grid
