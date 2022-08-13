-- The shared game stage state
local state = {
    grid = {
        left = {},
        right = {}
    }
}

local listeners = {}

function state:setGridInstance(url, side)
    self.grid[side].url = url

    msg.post(url, "sync_state", {
        side = side
    })
end

function state:setGridPosition(pos, side)
    go.set_position(pos, self.grid[side].url)
end

function state:registerListener(url, id)
    listeners[id] = url
end

function state:removeListener(id)
    listeners[id] = nil
end

function state:sendEvent(ev, data)
    for _, v in pairs(listeners) do
        msg.post(v, ev, data)
    end
end

return state
