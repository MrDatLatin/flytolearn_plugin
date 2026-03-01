--[[
    ftl_start.lua
	
	Creative Commons CC-BY-SA-NC 2023-12-06
	Jeffory J. Beckers
	Jemma Studios
]]
size = {c.ui_x, c.ui_y} -- set in flytolearn.lua
WHITE = {1, 1, 1, 1}
local bkgnd_img = loadImage ("ui_assets/options_back.png")
local roboto = loadFont ("/ui_assets/RobotoCondensed-Regular.ttf")
local font_size = 42

local UI_IMG_WIDTH = 3
local UI_IMG_HEIGHT = 4
local BUTTON_NAME = 5
local IMAGE_NAME = 6
local CUSTOM_CURSOR = 7
local CURSOR_IMG = 8

local page_ui = {}
page_ui[1] = {460, 0, 460, 70, "back", "back", false, "ui_assets/curs_finger.png"}
page_ui[2] = {0, 0, 460, 70, "set_all", "setall", false, "ui_assets/curs_finger.png"}
page_ui[3] = {615, 294, 35, 44, "dist_left", "left", false, "ui_assets/curs_finger.png"}
page_ui[4] = {650, 294, 75, 44, "dist_wt", "border", false, "ui_assets/curs_finger.png"}
page_ui[5] = {725, 294, 35, 44, "dist_right", "right", false, "ui_assets/curs_finger.png"}
page_ui[6] = {615, 244, 35, 44, "payload_left", "left", false, "ui_assets/curs_finger.png"}
page_ui[7] = {650, 244, 75, 44, "payload_wt", "border", false, "ui_assets/curs_finger.png"}
page_ui[8] = {725, 244, 35, 44, "payload_right", "right", false, "ui_assets/curs_finger.png"}
page_ui[9] = {615, 194, 35, 44, "fuel_left", "left", false, "ui_assets/curs_finger.png"}
page_ui[10] = {650, 194, 75, 44, "fuel_wt", "border", false, "ui_assets/curs_finger.png"}
page_ui[11] = {725, 194, 35, 44, "fuel_right", "right", false, "ui_assets/curs_finger.png"}
page_ui[12] = {615, 144, 35, 44, "time_left", "left", false, "ui_assets/curs_finger.png"}
page_ui[13] = {650, 144, 75, 44, "time_wt", "border", false, "ui_assets/curs_finger.png"}
page_ui[14] = {725, 144, 35, 44, "time_right", "right", false, "ui_assets/curs_finger.png"}

page_ui.num_elems = #page_ui


function onModuleInit ()

end

function update ()
    updateAll (components)
end

function draw ()
    drawTexture (bkgnd_img, 0, 0, c.ui_x, c.ui_y, WHITE)

    drawText(roboto, 687, 316-15, string.format ("%.1f", settings.distance_weight), font_size, true, false, TEXT_ALIGN_CENTER, WHITE)
    drawText(roboto, 687, 266-15, string.format ("%.1f", settings.payload_weight), font_size, true, false, TEXT_ALIGN_CENTER, WHITE)
    drawText(roboto, 687, 216-15, string.format ("%.1f", settings.fuel_weight), font_size, true, false, TEXT_ALIGN_CENTER, WHITE)
    drawText(roboto, 687, 166-15, string.format ("%.1f", settings.time_weight), font_size, true, false, TEXT_ALIGN_CENTER, WHITE)
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