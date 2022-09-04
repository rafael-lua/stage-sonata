local should = require "modules.should"
local helpers = {}

function helpers.deepcopy(item)
    if type(item) ~= "table" then
        return item
    end

    local res = {}
    for k, v in pairs(item) do
        res[k] = helpers.deepcopy(v)
    end

    return res
end

function helpers.deepmerge(base, item)
    if type(base) ~= "table" and type(item) ~= "table" then
        return base
    end

    for k, v in pairs(item) do
        local typeBase = type(item[k])
        local typeItem = type(item[k])
        local isTable = typeBase == "table" and typeItem == "table"
        if typeBase == typeItem then
            base[k] = isTable and helpers.deepmerge(base[k], item[k]) or item[k]
        end
    end

    return base
end

function helpers.coordTouchsRectangle(x, y, pos, width, height)
    local isWithinX = (x >= pos.x and x < (pos.x + width))
    local isWithinY = (y >= pos.y and y < (pos.y + height))

    return (isWithinX and isWithinY)
end

return helpers
