-- The shared game stage state
local state = {}

local listeners = {}

-- Sets a grid instance for the specified player[hash].
function state:setGridInstance(player_id, grid)
    self[player_id].grid = grid
end

function state:setGridPosition(pos, player_id)
    go.set_position(pos, self[player_id].grid.url)
end

function state:setPlayer(player_id)
    self[player_id] = {
        is_moving = {}
    }
end

function state:getPlayer(player_id)
    return self[player_id]
end

function state:updatePlayer(player_id, player_state)
    for k, v in pairs(player_state) do
        self[player_id][k] = v
    end
end

function state:setPlayerProp(player_id, key, value)
    self[player_id][key] = value
end

function state:pushToPlayerProp(player_id, key)
    if self[player_id][key] then
        table.insert(self[player_id][key], true)
    else
        self[player_id][key] = {}
        table.insert(self[player_id][key], true)
    end
end

function state:removeFromPlayerProp(player_id, key)
    if self[player_id][key] then
        table.remove(self[player_id][key])
    end
end

return state
