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

    msg.post(
        url, "sync_state", {
            side = side
        }
    )
end

function state:setGridPosition(pos, side)
    go.set_position(pos, self.grid[side].url)
end

function state:setPlayer(id)
    self.player_id = id
    self[id] = {
        is_moving = {}
    }
end

function state:getPlayer(id)
    return self[state.player_id]
end

function state:updatePlayer(player_state)
    for k, v in pairs(player_state) do
        self[state.player_id][k] = v
    end
end

function state:setPlayerProp(key, value)
    self[state.player_id][key] = value
end

function state:pushToPlayerProp(key)
    if self[state.player_id][key] then
        table.insert(self[state.player_id][key], true)
    else
        self[state.player_id][key] = {}
        table.insert(self[state.player_id][key], true)
    end
end

function state:removeFromPlayerProp(key)
    if self[state.player_id][key] then
        table.remove(self[state.player_id][key])
    end
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
