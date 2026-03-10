-- flexdash_ui_button.lua
local white = {1, 1, 1, 1}

local MOUSE_OFF = 1
local MOUSE_HOVER = 2
local MOUSE_DOWN = 3
local mouse_status = MOUSE_OFF


settings.ftl_logo.num_click_spots = settings.ftl_logo.num_click_spots + 1
local is_me = settings.ftl_logo.num_click_spots

defineProperty("button_name", "fd_big_button_down")
defineProperty("width", 48)
defineProperty("height", 48)
defineProperty("image_name", "fd_big_button_down")
defineProperty("hasCursor", false)
local button_image = {}
button_image[MOUSE_OFF] = sasl.gl.loadImage ("ui_assets/"..get(image_name).."_off.png", 0, 0, get(width), get(height))
button_image[MOUSE_HOVER] = sasl.gl.loadImage ("ui_assets/"..get(image_name).."_over.png", 0, 0, get(width), get(height))
button_image[MOUSE_DOWN] = sasl.gl.loadImage ("ui_assets/"..get(image_name).."_click.png", 0, 0, get(width), get(height))

function onMouseMove(component, x, y, button, parentX, parentY)
    return true
end

function onMouseDown(component, x, y, button, parentX, parentY)
    if settings.ftl_logo.owns_mousedown == 0 then
        settings.ftl_logo.owns_mousedown = is_me     -- only one clicky thing should have control of the mouseUp/mouseHold events or strange things happens
        if button == MB_LEFT then
            mouse_status = MOUSE_DOWN
        end
        settings.ftl_logo.doMouseDown (button, parentX, parentY, get(button_name))
    end
    return true
end

function onMouseUp(component, x, y, button, parentX, parentY)
    mouse_status = MOUSE_HOVER
    if settings.ftl_logo.owns_mousedown == is_me then
        if  x < 0 or y < 0 or x > get(position)[3] or y > get(position)[4] then
            mouse_status = MOUSE_OFF
        else
            settings.ftl_logo.doMouseUp (button, parentX, parentY, get(button_name))
        end
    else
        mouse_status = MOUSE_OFF
    end
    settings.ftl_logo.owns_mousedown = 0
    return true
end

function onMouseHold (component, x, y, button, parentX, parentY)
    if settings.ftl_logo.owns_mousedown == is_me then
        settings.ftl_logo.doMouseHold(button, parentX, parentY, get(button_name))
    end
    return true
end

function onMouseEnter()
    settings.ftl_logo.doMouseEnter(get(button_name))
    if settings.ftl_logo.owns_mousedown == is_me then

        mouse_status = MOUSE_DOWN
    else
        mouse_status = MOUSE_HOVER
    end
end

function onMouseLeave()
    settings.ftl_logo.doMouseLeave(get(button_name))
    mouse_status = MOUSE_OFF
end

local scroll_timer, scrolling = 0, false
function onMouseWheel(component, x, y, button, parentX, parentY, value)
    -- if scrolling then value = value * 5 end
    settings.ftl_logo.doMouseWheel (parentX, parentY, get(button_name), value)
    scroll_timer = os.clock()
    scrolling = true

end

function update()
    if os.clock() > scroll_timer + 0.3 then 
        scrolling = false
    end
    -- if get(hasCursor) then
    --     local curs =  (get(cursor))
    --     if scrolling then
    --         curs.shape =  sasl.gl.loadImage ("ui_assets/seat_off.png")
    --     else
    --         curs.shape = sasl.gl.loadImage ("ui_assets/cursor_updown.png")
    --     end
    -- end
end

function draw()
    sasl.gl.drawTexture ( button_image[mouse_status] , 0, 0, size[1] , size[2], white)
end


