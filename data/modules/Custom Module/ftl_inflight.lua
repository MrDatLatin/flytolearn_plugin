--[[
    ftl_score.lua
	
	Creative Commons CC-BY-SA-NC 2023-12-06
	Jeffory J. Beckers
	Jemma Studios
]]
size = {c.ui_x, c.ui_y} -- set in c90b.lua
WHITE = {1, 1, 1, 1}
local bkgnd_img = loadImage ("ui_assets/inflight_back.png")


local UI_IMG_WIDTH = 3
local UI_IMG_HEIGHT = 4
local BUTTON_NAME = 5
local IMAGE_NAME = 6
local CUSTOM_CURSOR = 7
local CURSOR_IMG = 8

local page_ui = {}
page_ui[1] = {0, 0, 920, 65, "cancel", "cancel", false, "ui_assets/curs_finger.png"}
page_ui[2] = {0, 65, 920, 115, "continue", "continue", true, "ui_assets/curs_finger.png"}
-- page_ui[3] = {0, 0, 460, 65, "options", "option", false, "ui_assets/curs_finger.png"}
-- page_ui[4] = {0, 65, 920, 115, "start", "start", false, "ui_assets/curs_finger.png"}
page_ui.num_elems = #page_ui


function onModuleInit ()

end

function update ()

    updateAll (components)
end

function draw ()
    drawTexture (bkgnd_img, 0, 0, c.ui_x, c.ui_y, WHITE)
    
    drawAll (components)
end

components = {}

for i=1, page_ui.num_elems do
    if page_ui[i][CUSTOM_CURSOR] then
        table.insert (components, ui_button { position = page_ui[i], width = page_ui[i][UI_IMG_WIDTH], height = page_ui[i][UI_IMG_HEIGHT],
                button_name = page_ui[i][BUTTON_NAME], image_name = page_ui[i][IMAGE_NAME], hasCursor = true, cursor = {
                    x = -16,
                    y = -16,
                    width = 32,
                    height = 32,
                    shape = sasl.gl.loadImage (page_ui[i][CURSOR_IMG]),
                    hideOSCursor = true
                    } }
                )
    else
        table.insert (components, ui_button { position = page_ui[i], width = page_ui[i][UI_IMG_WIDTH], height = page_ui[i][UI_IMG_HEIGHT],
            button_name = page_ui[i][BUTTON_NAME], image_name = page_ui[i][IMAGE_NAME]}
            )
    end
end