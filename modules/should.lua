local should = {
    be = {
        all = {}
    }
}

local Assert_All_Types = function(values, t)
    local assertion = true

    for _, v in pairs(values) do
        if type(v) ~= t then
            assertion = false
            break
        end
    end

    return assertion
end

function should.be.number(value, propertyName)
    propertyName = propertyName or "property"
    local assertMessage = "'" .. propertyName .. "' should be called with a number"

    assert(type(value) == "number", assertMessage)
end

function should.be.all.number(values, propertyName)
    assert(type(values) == "table",
        "'should.be.all.number' must be called with a flat table/array of values to be asserted")
    propertyName = propertyName or "property"
    local assertMessage = "'" .. propertyName .. "' should be called with a numbers"

    assert(Assert_All_Types(values, "number"), assertMessage)
end

function should.be.fn(value, propertyName)
    propertyName = propertyName or "property"
    local assertMessage = "'" .. propertyName .. "' should be called with a callback function"

    assert(type(value) == "function", assertMessage)
end

function should.be.table(value, propertyName)
    propertyName = propertyName or "property"
    local assertMessage = "'" .. propertyName .. "' should be called with a table"

    assert(type(value) == "table", assertMessage)
end

return should
