local math = math
local collider = {}

function collider.coordTouchsRectangle(x, y, pos, width, height)
    local isWithinX = (x >= pos.x and x < (pos.x + width))
    local isWithinY = (y >= pos.y and y < (pos.y + height))

    return (isWithinX and isWithinY)
end

return collider
