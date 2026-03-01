--[[
    ftl_logo.lua
	
	Creative Commons CC-BY-SA-NC 2024-01-25
	Jeffory J. Beckers
	Jemma Studios
]]
size = {c.logo_x, c.logo_y} -- set in c90b.lua
WHITE = {1, 1, 1, 0.5}
local logo_img = loadImage ("ui_assets/ftl_logo.png")
local show_logo = true


function settings.ftl_logo.doMouseEnter(button_name)
    if button_name == "ftl" then
        show_logo = false
    end
    -- if button_name == "page1" then
    --     mouse_in_tab = 1
    -- elseif button_name == "page2" then
    --     mouse_in_tab = 2
    -- elseif button_name == "page3" then
    --     mouse_in_tab = 3
    -- end
    -- settings.ftl_logo.show_tip = (
    --     (button_name == "front_bag") or
    --     (button_name == "front_bag")use
    -- )
end

function settings.ftl_logo.doMouseLeave(button_name)
    if button_name == "ftl" then
        show_logo = true
    end
    -- if button_name == "page1" and mouse_in_tab == 1 then
    --     mouse_in_tab = 0
    -- elseif button_name == "page2" and mouse_in_tab == 2 then
    --     mouse_in_tab = 0
    -- elseif button_name == "page3" and mouse_in_tab == 3 then
    --     mouse_in_tab = 0
    -- end
    settings.ftl_logo.show_tip = false
end

function settings.ftl_logo.doMouseUp (button, parentX, parentY, button_name, cid)
    -- if button_name == "page1" then
    --     settings.ftl_logo.page_number = 1
    -- elseif button_name == "page2" then
    --     settings.ftl_logo.page_number = 2
    -- elseif button_name == "page3" then
    --     settings.ftl_logo.page_number = 3
    -- else

    -- end
end

function settings.ftl_logo.doMouseHold (button, parentX, parentY, button_name, cid)
end

function settings.ftl_logo.doMouseDown (button, parentX, parentY, button_name, cid)
end

function settings.ftl_logo.doMouseWheel (parentX, parentY, button_name, value)
    if button_name == "ftl" then
        local n = settings.alpha + value/25
        if n < 0.25 then n = 0.25
        elseif n > 1 then n = 1 end
        settings.alpha = n
    end
end

function onModuleInit ()

end

function update ()
    updateAll (components)
end

function draw ()
    if show_logo then
        drawTexture (logo_img, 0, 0, c.logo_x, c.logo_y, WHITE)
    end

    drawAll (components)
end

components = {}

table.insert (components, ui_button { position ={0,0,c.logo_x, c.logo_y}, width = c.logo_x, height = c.logo_y, button_name = "ftl", image_name = "ftl"}
)


-- for i=1, wb_ui.num_elems do
--     if wb_ui[i][CUSTOM_CURSOR] then
--         table.insert (components, ui_button { position = wb_ui[i], width = wb_ui[i][UI_IMG_WIDTH], height = wb_ui[i][UI_IMG_HEIGHT],
--                 button_name = wb_ui[i][BUTTON_NAME], image_name = wb_ui[i][IMAGE_NAME], hasCursor = true, cursor = {
--                     x = -16,
--                     y = -16,
--                     width = 32,
--                     height = 32,
--                     shape = sasl.gl.loadImage (wb_ui[i][CURSOR_IMG]),
--                     hideOSCursor = true
--                     } }
--                 )
--     else
--         table.insert (components, ui_button { position = wb_ui[i], width = wb_ui[i][UI_IMG_WIDTH], height = wb_ui[i][UI_IMG_HEIGHT],
--             button_name = wb_ui[i][BUTTON_NAME], image_name = wb_ui[i][IMAGE_NAME]}
--             )
--     end
-- end