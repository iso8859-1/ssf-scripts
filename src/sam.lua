--[[
	SAM site management module for SSF

	Provides utilities to manage SAM sites, including detection of SEAD missiles
	and controlling SAM radar emissions.

	SAM groups are configured using either direct scripting or trigger zone properties in the mission editor.

	Trigger Zone Configuration:
	- Create a Trigger Zone with the property "ssf" set to true.
	- Add a property "group" with the name of the SAM group to configure.
	- SAM configuration properties can be added as needed:
	  - sam_defense: name of the strategy used for self-defense. "turn_off" turns off the radar.
	  - sam_detect_p: probability (0.0 to 1.0): Chance to detect SEAD missile per detection interval. Default value is 1.0
	  - sam_shutdown_time: time in seconds to keep radar off after SEAD detection. Default is 300 seconds.
	  - sam_detect_t: detection interval in seconds. Default is 10 seconds.
	  - sam_range: attack range for the SAM site (0.0 to 1.0, fraction of max range). Default is 1.0 (full range).
	  - pd_group: name of the point defense group to activate when SEAD is detected.
	  - pd_active_time: time in seconds to keep point defense active after SEAD detection. Default is 600 seconds.
--]]

SSF.Sam = SSF.Sam or {}
-- Table of SAM sites that are configured to defend themselves. Keyed by group name. Value is a table with configuration.
-- Table structure:
-- SSF.Sam.Defend = {
--    ["SAM Site Group Name"] = {
--        detection_chance = 0.8, -- Chance to detect SEAD missile per detection interval (0.0 to 1.0)
--        detection_interval = 10, -- Interval in seconds to check for SEAD missiles
--        shutdown_time = 300, -- Time in seconds to keep radar off after SEAD detection
--        range = 0.75, -- Attack range for the SAM site (0.0 to 1.0, fraction of max range)
-- 		  point_defense = "point_defense_group_name", -- Name of the point defense group to activate
--        point_defense_active_time = 600, -- Time in seconds to keep point defense active after SEAD detection
--    },
-- }
SSF.Sam.Defend = SSF.Sam.Defend or {} 

-- SEAD missile helper utilities
local _sead_missiles = {
	"X_58",
	"X_25MP",
	"Kh25MP_PRGS1VP",
	"AGM_88",
	"AGM_122",
	"AGM_45",
	"X_31P",
	"ALARM",
	"LD-10",
	"GBU_31_V_3B",
	"GBU_31",
	"GBU_31_V_2B",
	"GBU_31_V_4B",
	"GBU_32_V_2B",
	"GBU_38",
	"AGM_154",
	"AGM_154A",
	"AGM_84E",
	"AGM_84H",
	"AGM_86C",
	"AGM_62",
	"AGM_130",
	"GB-6",
	"GB-6-HE",
	"GB-6-SFW",
}

local _sead_set = {}
for _, v in ipairs(_sead_missiles) do
	_sead_set[v] = true
end

-- Returns true if `name` is a SEAD/strike weapon from the list, false otherwise.
function SSF.Sam.isSEADMissile(name)
	if type(name) ~= "string" then return false end
	return _sead_set[name] == true
end

function SSF.Sam.enableEmissions(sam_group, enable)
	SSF.Logger:info("Setting emissions for SAM site..." .. mist.utils.tableShow(sam_group))
	if not sam_group then
		SSF.Logger:error("No SAM group provided to enableEmissions")
		return
	end
	local controller = sam_group:getController()
	if not controller then
		SSF.Logger:error("No controller found for SAM site: " .. sam_group:getName())
		return
	end
	sam_group:enableEmission(enable)
	local state = enable and "enabled" or "disabled"
	SSF.Logger:info("Emissions " .. state .. " for SAM site: " .. sam_group:getName())
end

-- Checks for all configured SAM sites if it detects a SEAD missile
local function detect_sead_missile()
    SSF.Logger:info("Checking for SEAD missiles...")
    -- prototype with fixed values
    -- SSF.Logger:info("Disabling radar for SAM site: " .. sam_site.groupName)
	local dcs_sam_group = Group.getByName("Ground-1")
	if not dcs_sam_group then
		SSF.Logger:error("Could not find DCS group for SAM site: " .. sam_site.groupName)
		return
	end
	SSF.Sam.enableEmissions(dcs_sam_group, false)
    -- SSF.Sam.enableEmissions(sam_site, false)
end

local anti_radiation_launch = {}												
function anti_radiation_launch:onEvent(event)
    if event.id == world.event.S_EVENT_SHOT then
        local weapon = event.weapon
        if SSF.Sam.isSEADMissile(weapon:getTypeName()) then
            local text = "SEAD missile launched: " .. weapon:getTypeName()
            SSF.Logger:info(text)
            --mist.scheduleFunction(detect_sead_missile, {}, timer.getTime() + 1, 10, timer.getTime()+300)
			detect_sead_missile()
        end
    end
end

local function initialize_sam_defense()
	SSF.Logger:info("initializing SAM groups ...")
	-- iterate through SSF.Properties.UnitProperties to find SAM groups with defense configurations
	for group_name, properties in pairs(SSF.Properties.UnitProperties) do
		SSF.Logger:info("Checking group: " .. group_name .. ":" .. mist.utils.tableShow(properties))
		-- no need to check for ssf property, already done during properties loading
		if properties.sam_defense then
			SSF.Logger:info("Configuring SAM defense for group: " .. group_name)
			-- complete configuration with defaults
			local config = {
				detection_chance = tonumber(properties.sam_detect_p) or 1.0,
				detection_interval = tonumber(properties.sam_detect_t) or 10,
				shutdown_time = tonumber(properties.sam_shutdown_time) or 300,
				range = tonumber(properties.sam_range) or 1.0,
				point_defense = properties.pd_group or "",
				point_defense_active_time = tonumber(properties.pd_active_time) or 600,
			}
			SSF.Logger:info("SAM defense config for " .. group_name .. ": " .. mist.utils.tableShow(config))
			SSF.Sam.Defend[group_name] = config
		end
	end
end

SSF.Logger:msg("Loading SAM module...")
initialize_sam_defense()
world.addEventHandler(anti_radiation_launch)

