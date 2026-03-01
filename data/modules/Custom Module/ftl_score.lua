--[[
    ftl_score.lua
	
	Creative Commons CC-BY-SA-NC 2023-12-06
	Jeffory J. Beckers
	Jemma Studios
]]
size = {c.ui_x, c.ui_y} -- set in c90b.lua
WHITE  = {1, 1, 1, 1}
local RED    = {1, 0.3, 0.3, 1}
local YELLOW = {1, 1, 0.3, 1}
local bkgnd_img = loadImage ("ui_assets/score_back.png")

local roboto = loadFont ("/ui_assets/RobotoCondensed-Regular.ttf")
local font_size = 42

local UI_IMG_WIDTH = 3
local UI_IMG_HEIGHT = 4
local BUTTON_NAME = 5
local IMAGE_NAME = 6
local CUSTOM_CURSOR = 7
local CURSOR_IMG = 8

local page_ui = {}
page_ui[1] = {460, 0, 460, 65, "score_quit", "quit", false, "ui_assets/curs_finger.png"}
-- page_ui[2] = {167, 350, 219, 32, "flight_config", "flight_config", true, "ui_assets/curs_finger.png"}
-- page_ui[3] = {0, 0, 460, 65, "options", "option", false, "ui_assets/curs_finger.png"}
-- page_ui[4] = {0, 65, 920, 115, "start", "start", false, "ui_assets/curs_finger.png"}
page_ui.num_elems = #page_ui

local flightplan_txt, distance_txt, time_txt, payload_txt, fuel_txt, landing_txt, score_txt

function onModuleInit ()

end

function update ()
    flightplan_txt = "Flight from " .. c.start_airport.icao .. " to " .. c.end_airport.icao
    distance_txt = "Distance flown was " .. string.format ("%.2f", calc_dist) .. " NM"
    payload_txt = "Payload weight was " .. string.format ("%.2f", calc_load) .. " pounds"
    time_txt = "Flight time was " .. string.format ("%.1f", calc_time) .. " minutes"
    fuel_txt = "You consumed " .. string.format ("%.2f", calc_fuel) .. " pounds of fuel"
    if landing_dq then
        landing_txt = "Disqualified: " .. landing_dq_reason
        score_txt   = "DISQUALIFIED"
    elseif landing_penalty_pct > 0 then
        landing_txt = "Landing: Hard landing (-" .. landing_penalty_pct .. "% penalty)"
        score_txt   = "Final Score: " .. string.format("%.2f", final_score) .. " points"
    else
        landing_txt = "Landing: Clean"
        score_txt   = "Final Score: " .. string.format ("%.2f", final_score) .. " points"
    end

    updateAll (components)
end

function draw ()
    drawTexture (bkgnd_img, 0, 0, c.ui_x, c.ui_y, WHITE)

    drawText(roboto, c.ui_x/2, 382-15, flightplan_txt, font_size, true, false, TEXT_ALIGN_CENTER, WHITE)
    drawText(roboto, c.ui_x/2, 382-45-15, distance_txt, font_size, true, false, TEXT_ALIGN_CENTER, WHITE)
    drawText(roboto, c.ui_x/2, 382-90-15, payload_txt, font_size, true, false, TEXT_ALIGN_CENTER, WHITE)
    drawText(roboto, c.ui_x/2, 382-135-15, time_txt, font_size, true, false, TEXT_ALIGN_CENTER, WHITE)
    drawText(roboto, c.ui_x/2, 382-180-15, fuel_txt, font_size, true, false, TEXT_ALIGN_CENTER, WHITE)
    local landing_color = (landing_dq or landing_penalty_pct > 0) and YELLOW or WHITE
    local score_color   = landing_dq and RED or WHITE
    drawText(roboto, c.ui_x/2, 382-220-15, landing_txt, font_size, true, false, TEXT_ALIGN_CENTER, landing_color)
    drawText(roboto, c.ui_x/2, 382-260-15, score_txt, 60, true, false, TEXT_ALIGN_CENTER, score_color)
    
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