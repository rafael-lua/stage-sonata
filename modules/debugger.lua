-- A shared game debugger utility
local debugger = {}

local messages = {}
local mouse_state = {
    x = nil,
    y = nil
}

local colors = {
    white = vmath.vector4(1, 1, 1, 1),
    red = vmath.vector4(1, 0.15, 0.35, 1),
    green = vmath.vector4(0.35, 1, 0.15, 1),
    blue = vmath.vector4(0.15, 0.35, 1, 1)
}

function debugger.updateMouseState(x, y)
    mouse_state.x = x
    mouse_state.y = y
end

-- message can be either a string or a {text = "string", color = red|green|blue|white(default)}
function debugger.setMessage(id, message)
    messages[id] = message
end

function debugger.removeMessage(id)
    messages[id] = nil
end

local textSpacing = 24

function debugger.drawMessages()
    local windowW, windowH = window.get_size()
    local textY = windowH - 32
    local textX = 32
    local maxHeight = 688 - 16 - textSpacing -- we account for the default mouse message
    local offsetY = 0

    for k, v in pairs(messages) do
        if (offsetY <= maxHeight) then
            local text = ""
            local textColor = colors.white

            if type(v) == "string" then
                text = "[" .. k .. "]: " .. v
            else
                text = "[" .. k .. "]: " .. v.text
                textColor = colors[v.color] or colors.white
            end

            msg.post("@render:", "draw_debug_text", {
                text = text,
                position = vmath.vector3(textX, textY - offsetY, 1),
                color = textColor
            })
            offsetY = offsetY + textSpacing
        else
            pprint("DEBUGGER: MAX PRINT MESSAGES REACHED, EXTRA MESSAGES WILL BE HIDDEN.")
            break
        end
    end

    msg.post("@render:", "draw_debug_text", {
        text = "Mouse (x,y): " .. math.floor(mouse_state.x) .. ", " .. math.floor(mouse_state.y),
        position = vmath.vector3(32, 32 + math.floor(textSpacing / 2), 0),
        color = colors.white
    })
end

return debugger
