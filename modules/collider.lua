local math = math
local collider = {}

function collider.coordTouchsCell(x, y, pos, size)
    local isWithinX = (x >= pos.x and x < (pos.x + size))
    local isWithinY = (y >= pos.y and y < (pos.y + size))

    return (isWithinX and isWithinY)
end

return collider
