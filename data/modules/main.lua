--[[
	main.lua

]]

--------------------------------------------------------------------------------
-- Global settings
local project_name = "FlyToLearn Aviation Challenge"
local project_nickname = "FlyToLearn"
sasl.logInfo("Loading the " .. project_name .. " plugin...")

settings = {}
c = {} -- constants
drefs = {}
command_refs = {}

c.curr_version = "1.1.3"

settings.version = "1.1.3"
settings.distance_weight = 1
settings.payload_weight = 1
settings.fuel_weight = 1
settings.time_weight = 1
settings.alpha = 1
settings.min_flight_length = 2

--------------------------------------------------------------------------------
-- Only one of the following lines should be uncommented
sasl.setLogLevel ( LOG_DEBUG )  -- use for development
-- sasl.setLogLevel ( LOG_INFO )  -- use for distribution
--------------------------------------------------------------------------------

-- These make SASL light.  You may need to turn one or more on for high level magic
sasl.options.setAircraftPanelRendering ( false )
sasl.options.set3DRendering ( false )
sasl.options.setInteractivity ( true )

include "keyboard_handler"

timer_lib = {}
debug_lib = {}

function debug_lib.on_debug(tString)
	if getLogLevel() == LOG_DEBUG then print ("DEBUG MODE! "..tString) end
end

debug_lib.on_debug ("********************* DEBUG MODE IS ON ************************")
debug_lib.on_debug ("*  If you are reading this I screwed up before distribution.  *")
debug_lib.on_debug ("***************************************************************")


------------------------------------------------------------------------------------
config = {}
config_path = sasl.getProjectPath() .. "/Custom Module/flytolearn_config.ini"
local config_size = 0
if isFileExists ( config_path ) then 
	config = sasl.readConfig ( config_path , "ini" )
	for i, v in pairs (config) do
		settings[i] = v
		config_size = config_size + 1
	end
	--[[
		if we ever get to a point where the config file requires version control we can add it below.
		for now we'll just update the version number to the current.
		]]
	if settings.version ~= c.curr_version then
		settings.version = c.curr_version
	end 
	--
else
	local warn_hdr = "["..project_nickname.."]:[WARNING] "
	sasl.log(LOG_WARN, false, warn_hdr, "------------------------------------------------------------")
	sasl.log(LOG_WARN, false, warn_hdr, "Could not find "..project_name.." configuration named...")
	sasl.log(LOG_WARN, false, warn_hdr, config_path)
	sasl.log(LOG_WARN, false, warn_hdr, "Plugin will run with default configuration")
	sasl.log(LOG_WARN, false, warn_hdr, "------------------------------------------------------------")
	for k,v in pairs(settings) do  --if we don't have a config file already, we'll populate the config table with any default settings
		config[k] = v
		config_size = config_size + 1
	end
end

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

components = {
	timer_library {}, -- must be first in the order for other components to use it.
	flytolearn {}
}

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

function onModuleDone ()
	if sasl.writeConfig ( config_path , "ini" , config) then
		sasl.logInfo (project_name .. " settings saving to "..config_path)
	else
		sasl.logError("Error writing " .. project_name .. " settings to "..config_path)
	end
end