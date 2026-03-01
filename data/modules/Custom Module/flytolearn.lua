--[[
    flytolearn.lua
]]

--- defined properties
-- defineProperty("My_sample_setting", 2.00)

--- constants
c.ui_x, c.ui_y = 920, 520 -- size of main ui window
c.logo_x, c.logo_y = 278, 84 -- size of FTL logo

c.start_airport = {}
c.start_airport.icao = "TEST"
c.end_airport = {}
c.end_airport.icao = "TEST"
c.screen_change = false

MTRS_PER_MILE = 1852
KGS_TO_LBS = 0.453592

screen_x, screen_y, screen_width, screen_height = sasl.windows.getScreenBoundsGlobal ()
local old_screen_x, old_screen_y, old_screen_width, old_screen_height = screen_x, screen_y, screen_width, screen_height

start_time, start_fuel, start_dist, payload_wt = 0,0,0,0
end_time, end_fuel, end_dist, final_score = 0,0,0,0
calc_dist, calc_load, calc_fuel, calc_time = 0,0,0,0
weighted_dist, weighted_load, weighted_fuel, weighted_time = 0,0,0,0



-- constants: flight phase
FTL_PHASE_LIMBO = 0
FTL_PHASE_DEPARTING = 1
FTL_PHASE_INFLIGHT = 2
FTL_PHASE_LANDED = 3
FTL_PHASE_ENDED = 4

--- variables
settings.ftl_logo = {}
settings.ftl_logo.num_click_spots = 0
settings.ftl_logo.owns_mousedown = 0
settings.ftl_logo.show_tip = false

flight_phase = FTL_PHASE_LIMBO

local scrolling = false

flight_summary = {}
--- dataref lookups and command handlers
xp_battery_array = globalPropertyfa ("sim/cockpit2/electrical/battery_on")

xp_flight_config = findCommand ("sim/operation/toggle_flight_config")
xp_lat = globalPropertyf ("sim/flightmodel/position/latitude")
xp_lon = globalPropertyf ("sim/flightmodel/position/longitude")
xp_dist = globalPropertyf ("sim/flightmodel/controls/dist")
xp_flight_time = globalPropertyf ("sim/time/total_flight_time_sec")
xp_total_weight = globalPropertyf ("sim/flightmodel/weight/m_total")
xp_fuel_weight = globalPropertyf ("sim/flightmodel/weight/m_fuel_total")
xp_empty_weight = globalPropertyf ("sim/aircraft/weight/acf_m_empty")
xp_ground_speed = globalPropertyf ("sim/flightmodel2/position/groundspeed")
xp_on_ground = globalPropertyi ("sim/flightmodel/failures/onground_all")
xp_sim_speed = globalPropertyi ("sim/time/sim_speed")
xp_gnd_speed1 = globalPropertyi ("sim/time/ground_speed")
xp_gnd_speed2 = globalPropertyi ("sim/time/ground_speed_flt")
xp_gforce = globalPropertyf ("sim/flightmodel/forces/g_nrml")
xp_vs_fpm = globalPropertyf ("sim/flightmodel/position/vh_ind_fpm")


-- xp_sim_speed_cmd = findCommand ("sim/operation/flightmodel_speed_change")
-- xp_sim_groundspeed_cmd = findCommand ("sim/operation/ground_speed_change")

--- function library
function findAirport(lat, long)
    local id = findNavAid (nil, nil, lat, long, nil, NAV_AIRPORT)
    return id, getNavAidInfo ( id )
    
end

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
    local n = 0
    scrolling = false
    if button_name == "ftl" then
        if flight_phase == FTL_PHASE_LIMBO then
            start_popup:setIsVisible(true)
        else
            inflight_popup:setIsVisible(true)
        end
    elseif button_name == "cancel" then
        inflight_popup:setIsVisible(false)
        flight_phase = FTL_PHASE_LIMBO
    elseif button_name == "continue" then
        inflight_popup:setIsVisible(false)
    elseif button_name == "reload" then
        sasl.scheduleProjectReboot ()
    elseif button_name == "set_all" then
        settings.distance_weight = 1.0
        settings.payload_weight = 1.0
        settings.fuel_weight = 1.0
        settings.time_weight = 1.0
    elseif button_name == "start" then
        c.start_airport.id, c.start_airport.type , c.start_airport.arptLat , c.start_airport.arptLon , c.start_airport.height , c.start_airport.freq , c.start_airport.heading , 
        c.start_airport.icao , c.start_airport.name , c.start_airport.inCurDSF = findAirport(get(xp_lat), get(xp_lon))
        flight_phase = FTL_PHASE_DEPARTING
        start_popup:setIsVisible(false)
    elseif button_name == "quit" then
        start_popup:setIsVisible(false)
    elseif button_name == "flight_config" then
        commandOnce (xp_flight_config)
    elseif button_name == "options" then
        start_popup:setIsVisible(false)
        options_popup:setIsVisible(true)
    elseif button_name == "back" then
        start_popup:setIsVisible(true)
        options_popup:setIsVisible(false)
    elseif button_name == "dist_left" then
        settings.ftl_logo.doMouseWheel (parentX, parentY, "dist_wt", -1)
    elseif button_name == "dist_right" then
        settings.ftl_logo.doMouseWheel (parentX, parentY, "dist_wt", 1)
    elseif button_name == "payload_left" then
        settings.ftl_logo.doMouseWheel (parentX, parentY, "payload_wt", -1)
    elseif button_name == "payload_right" then
        settings.ftl_logo.doMouseWheel (parentX, parentY, "payload_wt", 1)
    elseif button_name == "fuel_left" then
        settings.ftl_logo.doMouseWheel (parentX, parentY, "fuel_wt", -1)
    elseif button_name == "fuel_right" then
        settings.ftl_logo.doMouseWheel (parentX, parentY, "fuel_wt", 1)
    elseif button_name == "time_left" then
        settings.ftl_logo.doMouseWheel (parentX, parentY, "time_wt", -1)
    elseif button_name == "time_right" then
        settings.ftl_logo.doMouseWheel (parentX, parentY, "time_wt", 1)
    elseif button_name == "score_quit" then
        flight_phase = FTL_PHASE_LIMBO
        score_popup:setIsVisible(false)
    end
    -- if button_name == "page1" then
    --     settings.ftl_logo.page_number = 1
    -- elseif button_name == "page2" then
    --     settings.ftl_logo.page_number = 2
    -- elseif button_name == "page3" then
    --     settings.ftl_logo.page_number = 3
    -- else

    -- end
end

local timer

function settings.ftl_logo.doMouseHold (button, parentX, parentY, button_name, cid)
    if  button_name == "dist_left" or
        button_name == "dist_right" or
        button_name == "payload_left" or
        button_name == "payload_right" or
        button_name == "fuel_left" or
        button_name == "fuel_right" or
        button_name == "time_left" or
        button_name == "time_right"
        then
        if timer + 0.5 <= os.clock() then
            scrolling = true
        end
    end
    if scrolling then
        if button_name == "dist_left" then
            if timer+0.1 <= os.clock() then
                timer = os.clock()
                settings.ftl_logo.doMouseWheel (parentX, parentY, "dist_wt", -1)
            end
        elseif button_name == "dist_right" then
            if timer+0.1 <= os.clock() then
                timer = os.clock()
                settings.ftl_logo.doMouseWheel (parentX, parentY, "dist_wt", 1)
            end
        elseif button_name == "payload_left" then
            if timer+0.1 <= os.clock() then
                timer = os.clock()
                settings.ftl_logo.doMouseWheel (parentX, parentY, "payload_wt", -1)
            end
        elseif button_name == "payload_right" then
            if timer+0.1 <= os.clock() then
                timer = os.clock()
                settings.ftl_logo.doMouseWheel (parentX, parentY, "payload_wt", 1)
            end
        elseif button_name == "fuel_left" then
            if timer+0.1 <= os.clock() then
                timer = os.clock()
                settings.ftl_logo.doMouseWheel (parentX, parentY, "fuel_wt", -1)
            end
        elseif button_name == "fuel_right" then
            if timer+0.1 <= os.clock() then
                timer = os.clock()
                settings.ftl_logo.doMouseWheel (parentX, parentY, "fuel_wt", 1)
            end
        elseif button_name == "time_left" then
            if timer+0.1 <= os.clock() then
                timer = os.clock()
                settings.ftl_logo.doMouseWheel (parentX, parentY, "time_wt", -1)
            end
        elseif button_name == "time_right" then
            if timer+0.1 <= os.clock() then
                timer = os.clock()
                settings.ftl_logo.doMouseWheel (parentX, parentY, "time_wt", 1)
            end
        end
    end
end

function settings.ftl_logo.doMouseDown (button, parentX, parentY, button_name, cid)
    if  button_name == "dist_left" or
        button_name == "dist_right" or
        button_name == "payload_left" or
        button_name == "payload_right" or
        button_name == "fuel_left" or
        button_name == "fuel_right" or
        button_name == "time_left" or
        button_name == "time_right"
        then
            timer = os.clock()

    end
end

function settings.ftl_logo.doMouseWheel (parentX, parentY, button_name, value)
    local n = 0
    if button_name == "ftl" then

    elseif button_name == "dist_wt" then
        n = settings.distance_weight + value/10
        if n < 0.5 then n = 0.5
        elseif n > 2 then n = 2 end
        settings.distance_weight = n
    elseif button_name == "payload_wt" then
        n = settings.payload_weight + value/10
        if n < 0.5 then n = 0.5
        elseif n > 2 then n = 2 end
        settings.payload_weight = n
    elseif button_name == "fuel_wt" then
        n = settings.fuel_weight + value/10
        if n < 0.5 then n = 0.5
        elseif n > 2 then n = 2 end
        settings.fuel_weight = n
    elseif button_name == "time_wt" then
        n = settings.time_weight + value/10
        if n < 0.5 then n = 0.5
        elseif n > 2 then n = 2 end
        settings.time_weight = n
    elseif button_name == "status" then
        n = settings.alpha + value/25
        if n < 0.25 then n = 0.25
        elseif n > 1 then n = 1 end
        settings.alpha = n
    end
end

local pop_x, pop_y = 0, 0

ftl_logo_frame = contextWindow {
	name = "Fly To Learn logo",
	position = {pop_x, pop_y, screen_width, c.logo_y+300},
	savePosition = true;
	noBackground = true;
	noResize = true;
    noMove = true;
    noDecore = true;
	visible = false;
    gravity = {1, 0, 0, 1};
	proportionalToXWindow = false;
	components = {
		ftl_logo {
			position = {0, 0, screen_width, c.logo_y},
			maximumSize = {screen_width, c.logo_y},
		}
	}
  }

pop_x, pop_y = screen_width/2 - c.ui_x/2, screen_height/2 - c.ui_y/2
start_popup = contextWindow {
	name = "Fly To Learn Start Page",
	position = {pop_x-50, pop_y-50, c.ui_x+100, c.ui_y+100},
	savePosition = true;
	noBackground = true;
	noResize = true;
    noMove = true;
    noDecore = true;
	visible = false;
    gravity = {0.5, 0.5, 0, 0};
	proportionalToXWindow = false;
	components = {
		ftl_start {
			position = {50, 50, c.ui_x, c.ui_y},
			maximumSize = {c.ui_x, c.ui_y},
		}
	}
  }

options_popup = contextWindow {
	name = "Fly To Learn Options Page",
	position = {pop_x-50, pop_y-50, c.ui_x+100, c.ui_y+100},
	savePosition = true;
	noBackground = true;
	noResize = true;
    noMove = true;
    noDecore = true;
	visible = false;
	proportionalToXWindow = false;
	components = {
		ftl_options {
			position = {50, 50, c.ui_x, c.ui_y},
			maximumSize = {c.ui_x, c.ui_y},
		}
	}
  }

  
reload_popup = contextWindow {
	name = "Fly To Learn Reboot Page",
	position = {pop_x-50, pop_y-50, 700, 500},
	savePosition = true;
	noBackground = true;
	noResize = true;
    noMove = true;
    noDecore = true;
	visible = false;
	proportionalToXWindow = false;
	components = {
		ftl_reboot {
			position = {50, 50, 600, 400},
			maximumSize = {600, 400},
		}
	}
  }

  score_popup = contextWindow {
	name = "Fly To Learn Score Page",
	position = {pop_x-50, pop_y-50, c.ui_x+100, c.ui_y+100},
	savePosition = true;
	noBackground = true;
	noResize = true;
    noMove = true;
    noDecore = true;
	visible = false;
	proportionalToXWindow = false;
	components = {
		ftl_score {
			position = {50, 50, c.ui_x, c.ui_y},
			maximumSize = {c.ui_x, c.ui_y},
		}
	}
  }
inflight_popup = contextWindow {
	name = "Fly To Learn Inflight Page",
	position = {pop_x-50, pop_y-50, c.ui_x+100, c.ui_y+100},
	savePosition = true;
	noBackground = true;
	noResize = true;
    noMove = true;
    noDecore = true;
	visible = false;
	proportionalToXWindow = false;
	components = {
		ftl_inflight {
			position = {50, 50, c.ui_x, c.ui_y},
			maximumSize = {c.ui_x, c.ui_y},
		}
	}
  }

  function show_flytolearn ()
    if ftl_logo_frame:isVisible () then
        ftl_logo_frame:setIsVisible (false)
        sasl.setMenuItemName(flytolearn_menu, flytolearn_startitem, "Show Fly To Learn")
    else
        ftl_logo_frame:setIsVisible (true)
        sasl.setMenuItemName(flytolearn_menu, flytolearn_startitem, "Hide Fly To Learn")
    end
end

flytolearn_menuitem = appendMenuItem (PLUGINS_MENU_ID, "Fly To Learn")
flytolearn_menu = createMenu ("", PLUGINS_MENU_ID, flytolearn_menuitem)
flytolearn_startitem = appendMenuItem (flytolearn_menu, "Show Fly To Learn", show_flytolearn)

function write_flight_info ()
    flight_log_name = sasl.getXPlanePath () .. "flytolearn_summary_"..os.date("%Y_%b_%d_%H_%M_%S")..".info"

    local tLines = {}
    table.insert(tLines, "FlyToLearn Aviation Challenge Summary")
    table.insert(tLines, "Plugin Version: ".. c.curr_version)
    table.insert(tLines, "Date: "..flight_summary.date)
    table.insert(tLines, "Time: "..flight_summary.time)
    table.insert(tLines, "Departure Airport: ".. flight_summary.departure)
    table.insert(tLines, "Arrival Airport: ".. flight_summary.arrival)
    table.insert(tLines, "-----------------------------")
    table.insert(tLines, "X-Plane Raw Data")
    table.insert(tLines, "Flight distance (meters): " .. flight_summary.xp_dist_in_m)
    table.insert(tLines, "Payload weight (kgs): " .. flight_summary.xp_payload_kg)
    table.insert(tLines, "Elapsed Time (seconds): " .. flight_summary.xp_time)
    table.insert(tLines, "Fuel Consumed (kgs): " .. flight_summary.xp_fuel_weight)
    table.insert(tLines, "-----------------------------")
    table.insert(tLines, "Flight Distance: ".. flight_summary.flight_distance)
    table.insert(tLines, "Flight Payload: ".. flight_summary.flight_payload)
    table.insert(tLines, "Flight Time: " .. flight_summary.flight_time)
    table.insert(tLines, "Fuel Consumed: " .. flight_summary.flight_fuel)
    table.insert(tLines, "Landing Force: " .. flight_summary.landing_force)
    table.insert(tLines, "Landing Rate: " .. flight_summary.vert_speed)
    table.insert(tLines, "Score weight (distance): " .. flight_summary.score_weight_distance)
    table.insert(tLines, "Score weight (payload): " .. flight_summary.score_weight_payload)
    table.insert(tLines, "Score weight (time): " .. flight_summary.score_wieght_time)
    table.insert(tLines, "Score weight (fuel): " .. flight_summary.score_weight_fuel)
    table.insert(tLines, "Final Score: " .. flight_summary.final_score)

    local current_file = assert(io.open(flight_log_name, "w"))        -- file object of fName
    io.output(current_file)

    for i, line in ipairs(tLines) do -- load each line of the obj text
        current_file:write (line.."\n")
    end
    io.close(current_file) -- we have the data now, so we can close this file.
	-- if sasl.writeConfig ( flight_log_name , "info" , flight_summary) then
	-- 	sasl.logInfo ("FlyToLearn flight summary saved to: "..config_path)
	-- else
	-- 	sasl.logError("Error writing FlyToLearn flight summary to "..config_path)
	-- end
end


function onModuleInit ()
    -- runs the first time the aircraft is loaded.  You want to put all initial state settings in here to be sure the plugin is fully loaded and "running".
end

--- main

function force_sim_speed_to_one ()
    set (xp_sim_speed, 1)
    set (xp_gnd_speed1, 1)
    set (xp_gnd_speed2, 1)
end

function update ()

    if c.screen_change then c.screen_change = false end
    screen_x, screen_y, screen_width, screen_height = sasl.windows.getScreenBoundsGlobal ()
    if screen_width ~= old_screen_width or screen_height ~= old_screen_height then
        reload_popup:setIsVisible (true)
        start_popup:setIsVisible(false)
        options_popup:setIsVisible(false)
    end
    local on_ground = get (xp_on_ground) == 1
    local xptime, xpfuel, xpdist, xpspeed = get(xp_flight_time), get(xp_fuel_weight), get(xp_dist), get(xp_ground_speed)
    if flight_phase == FTL_PHASE_INFLIGHT then
        force_sim_speed_to_one ()
    end
    if flight_phase == FTL_PHASE_DEPARTING then
        force_sim_speed_to_one ()
        if not on_ground then
            flight_phase = FTL_PHASE_INFLIGHT
            start_time = xptime -- in seconds
            start_fuel = xpfuel -- in kgs
            start_dist = xpdist -- in meters
            payload_wt = get(xp_total_weight) - get(xp_empty_weight) - get(xp_fuel_weight) -- in kgs

        end
    elseif flight_phase == FTL_PHASE_INFLIGHT and on_ground then
        if xptime - start_time >= (settings.min_flight_length * 60) then -- JJB 2024-03-23: added min flight length
            flight_phase = FTL_PHASE_LANDED
            end_time = xptime - start_time
            end_fuel = start_fuel - xpfuel
            end_dist = xpdist - start_dist
            c.end_airport.id, c.end_airport.type , c.end_airport.arptLat , c.end_airport.arptLon , c.end_airport.height , c.end_airport.freq , c.end_airport.heading , 
            c.end_airport.icao , c.end_airport.name , c.end_airport.inCurDSF = findAirport(get(xp_lat), get(xp_lon))
            -- Distance X Load / time x gas = score  JJB 2024-03-22: removed groups of parenthesis
            calc_dist = end_dist / MTRS_PER_MILE
            calc_load = payload_wt / KGS_TO_LBS
            calc_time = end_time / 60 -- seconds converted to minutes
            calc_fuel = end_fuel / KGS_TO_LBS
            weighted_dist = (calc_dist * settings.distance_weight)
            weighted_load = (calc_load * settings.payload_weight)
            weighted_time = (calc_time * settings.time_weight)
            weighted_fuel = (calc_fuel * settings.fuel_weight)
            
            final_score = (weighted_dist * weighted_load) / (weighted_time * weighted_fuel) * 100
            flight_summary.date = os.date("%x")
            flight_summary.time = os.date("%X")
            flight_summary.departure = "["..c.start_airport.icao.."] "..c.start_airport.name
            flight_summary.arrival = "["..c.end_airport.icao.."] "..c.end_airport.name
            flight_summary.xp_dist_in_m = string.format ("%.4f", end_dist) .. " meters"
            flight_summary.xp_payload_kg = string.format ("%.4f", payload_wt) .. " kgs"
            flight_summary.xp_fuel_weight = string.format ("%.4f", end_fuel) .. " kgs"
            flight_summary.xp_time = string.format ("%.1f", end_time) .. " seconds"
            flight_summary.flight_distance = string.format ("%.4f", calc_dist) .. " miles"
            flight_summary.flight_payload = string.format ("%.4f", calc_load) .. " lbs"
            flight_summary.flight_time = string.format ("%.4f", calc_time) .. " minutes"
            flight_summary.flight_fuel = string.format ("%.4f", calc_fuel) .. " lbs"
            flight_summary.landing_force = string.format ("%.4f", get(xp_gforce)) .. " G"
            flight_summary.vert_speed = string.format ("%.4f", get (xp_vs_fpm)) .. " fpm"
            flight_summary.score_weight_distance = string.format ("%.1f", settings.distance_weight)
            flight_summary.score_weight_payload = string.format ("%.1f", settings.payload_weight)
            flight_summary.score_wieght_time = string.format ("%.1f", settings.time_weight)
            flight_summary.score_weight_fuel = string.format ("%.1f", settings.fuel_weight)
            flight_summary.final_score = string.format ("%.2f", final_score) .. " points"
            write_flight_info ()
        else  -- JJB 2024-03-23: added min flight length
            flight_phase = FTL_PHASE_DEPARTING -- JJB 2024-03-23: added min flight length
        end -- JJB 2024-03-23: added min flight length
    elseif flight_phase == FTL_PHASE_LANDED and get(xp_ground_speed) <= 0.01 then
        flight_phase = FTL_PHASE_ENDED
        score_popup:setIsVisible(true)
    end


    -- updateAll (components)
end

function onModuleShutdown()
    config.distance_weight = settings.distance_weight
    config.payload_weight = settings.payload_weight
    config.fuel_weight = settings.fuel_weight
    config.time_weight = settings.time_weight
    config.alpha = settings.alpha
    config.min_flight_length = settings.min_flight_length
end
