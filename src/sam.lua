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
	  - sam_range: attack range for the SAM site (0.0 to 1.0, fraction of max range). Default is 1.0 (full range).
	  - pd_group: name of the point defense group to activate when SEAD is detected.
	  - pd_active_time: time in seconds to keep point defense active after SEAD detection. Default is 600 seconds.
	- SAM detection will be performed at intervals defined by the global config property "sam_detect_t" (default 10 seconds).
--]]

SSF.Sam = SSF.Sam or {}
-- Table of SAM sites that are configured to defend themselves. Keyed by group name. Value is a table with configuration.
-- Table structure:
-- SSF.Sam.Defend = {
--    ["SAM Site Group Name"] = {
--        detection_chance = 0.8, -- Chance to detect SEAD missile per detection interval (0.0 to 1.0)
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

SSF.Sam.DefenseStrategy = {
	NONE = 0,
	TURN_OFF = 1,
	TURN_OFF_EVADE = 2,
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

-- Enables or disables radar emissions for the SAM site.
-- sam_group_name: Name of the SAM group representing the SAM site.
-- enable: boolean, true to enable emissions, false to disable.
function SSF.Sam.enableEmissions(sam_group_name, enable)
	local sam_group = Group.getByName(sam_group_name)
	if not sam_group then
		SSF.Logger:error("No SAM group provided to enableEmissions: " .. tostring(sam_group_name))
		return
	end
	local controller = sam_group:getController()
	if not controller then
		SSF.Logger:error("No controller found for SAM site: " .. sam_group_name)
		return
	end
	sam_group:enableEmission(enable)
	if SSF.Sam.Defend[sam_group_name] then
		SSF.Sam.Defend[sam_group_name].active = enable
	end
	local state = enable and "enabled" or "disabled"
	SSF.Logger:info("Emissions " .. state .. " for SAM site: " .. sam_group_name)
end

-- Sets the engagement range restriction for the SAM site as a fraction (0.0 to 1.0) of max range.
-- sam_group_name: Name of the SAM group representing the SAM site.
-- range_fraction: 0.0 disables engagement, 1.0 is full range.
function SSF.Sam.restrictEngagementRange(sam_group_name, range_fraction)
	local sam_group = Group.getByName(sam_group_name)
	if not sam_group then
		SSF.Logger:error("No SAM group provided to restrictEngagementRange: " .. tostring(sam_group_name))
		return
	end
	if (range_fraction < 0.0) then
		SSF.Logger:error("Invalid range_fraction: " .. range_fraction .. ". Must be between 0.0 and 1.0")
		range_fraction = 0.0
	end
	if (range_fraction > 1.0) then
		SSF.Logger:error("Invalid range_fraction: " .. range_fraction .. ". Must be between 0.0 and 1.0")
		range_fraction = 1.0
	end
	local controller = sam_group:getController()
	if not controller then
		SSF.Logger:error("No controller found for SAM site: " .. sam_group:getName())
		return
	end
	controller:setOption(AI.Option.Ground.id.AC_ENGAGEMENT_RANGE_RESTRICTION, range_fraction)
	SSF.Logger:info("Engagement range set to " .. range_fraction .. "% for SAM site: " .. sam_group:getName())
end

-- Sets the SAM site's alarm state to GREEN (no operations).
-- sam_group_name: Name of the SAM group representing the SAM site.
function SSF.Sam.setAlarmStateGreen(sam_group_name)
	local sam_group = Group.getByName(sam_group_name)
	if not sam_group then
		SSF.Logger:error("No SAM group provided to setStateGreen: " .. tostring(sam_group_name))
		return
	end
	if sam_group:getCategory() ~= Group.Category.GROUND then
		SSF.Logger:error("Alarmstate can't be set - Group is not a ground unit: " .. sam_group_name)
		return
	end
	local controller = sam_group:getController()
	if not controller then
		SSF.Logger:error("No controller found for SAM site: " .. sam_group_name)
		return
	end
	controller:setOption( AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.GREEN)
	SSF.Logger:info("SAM site set to STATE GREEN: " .. sam_group_name)
end

-- Sets the SAM site's alarm state to RED (heightened alert).
-- sam_group_name: Name of the SAM group representing the SAM site.
function SSF.Sam.setAlarmStateRed(sam_group_name)
	local sam_group = Group.getByName(sam_group_name)
	if not sam_group then
		SSF.Logger:error("No SAM group provided to setAlarmStateRed: " .. tostring(sam_group_name))
		return
	end
	if sam_group:getCategory() ~= Group.Category.GROUND then
		SSF.Logger:error("Alarmstate can't be set - Group is not a ground unit: " .. sam_group_name)
		return
	end
	local controller = sam_group:getController()
	if not controller then
		SSF.Logger:error("No controller found for SAM site: " .. sam_group_name)
		return
	end
	controller:setOption( AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)
	SSF.Logger:info("SAM site set to STATE RED: " .. sam_group_name)
end

-- Applies engagement range restrictions to all configured SAM sites.
function SSF.Sam.applyRangeRestrictionToAll()
	for sam_group_name, config in pairs(SSF.Sam.Defend) do
		SSF.Logger:info("Applying range restriction to SAM site: " .. sam_group_name .. " with range: " .. config.range)
		SSF.Sam.restrictEngagementRange(sam_group_name, config.range)
	end
end

-- Checks if a SAM site detects the given weapon.
-- sam_group_name: Name of the SAM group representing the SAM site.
-- weapon: DCS weapon object to check for detection.
-- Returns true if detected, false otherwise.
local function weapon_detected_by_sam(sam_group_name, weapon)
	local sam_group = Group.getByName(sam_group_name)
	if not sam_group then
		SSF.Logger:error("No SAM group found for detection: " .. tostring(sam_group_name))
		return false
	end
	local controller = sam_group:getController()
	if not controller then
		SSF.Logger:error("No controller found for SAM site during detection: " .. sam_group_name)
		return false
	end
	local detection_result = controller:isTargetDetected(weapon)
	return detection_result.detected
end

-- Returns true with probability p (0.0 to 1.0), false otherwise.
local function random_chance(p)
	local rand_value = math.random()
	return rand_value <= p
end

-- Checks for all configured SAM sites if it detects a SEAD missile
local function detect_sead_missile(weapon)
	-- check if weapon still exists and re-schedule function
	if weapon and weapon:isExist() then
		timer.scheduleFunction(detect_sead_missile, weapon, timer.getTime() + SSF.Sam.Defend.sam_detect_t)
	end
    -- iterate through all configured SAM sites
	for sam_group_name, config in pairs(SSF.Sam.Defend) do
		-- check if SAM sit is active, otherwise skip
		if not config.active then
			goto continue
		end
		-- check if SAM detects the SEAD missile based on Controller.isTargetDetected and detection chance
		local detected = weapon_detected_by_sam(sam_group_name, weapon)
		local chance_ok = random_chance(config.detection_chance)
		SSF.Logger:info("SAM site '" .. sam_group_name .. "' detection check for weapon '" .. weapon:getTypeName() .. "': detected=" .. tostring(detected) .. ", chance_ok=" .. tostring(chance_ok))
		if detected and chance_ok then
			if config.defense_strategy == SSF.Sam.DefenseStrategy.TURN_OFF or config.defense_strategy == SSF.Sam.DefenseStrategy.TURN_OFF_EVADE then
				-- disable emissions
				SSF.Sam.enableEmissions(sam_group_name, false)
				-- schedule re-enabling emissions after shutdown_time
				timer.scheduleFunction(SSF.Sam.enableEmissions, {sam_group_name, true}, timer.getTime() + config.shutdown_time)
				SSF.Logger:info("SAM site '" .. sam_group_name .. "' radar turned OFF for " .. config.shutdown_time .. " seconds due to SEAD detection.")
			end
			-- check point_defense and activate if configured
			if config.point_defense and config.point_defense ~= "" then
				SSF.Sam.enableEmissions(config.point_defense, true)
				-- schedule disabling point defense after active_time
				timer.scheduleFunction(SSF.Sam.enableEmissions, {config.point_defense, false}, timer.getTime() + config.point_defense_active_time)
				SSF.Logger:info("Point defense group '" .. config.point_defense .. "' activated for " .. config.point_defense_active_time .. " seconds due to SEAD detection by SAM site '" .. sam_group_name .. "'.")
			end
		end

		-- react based on defense strategy
		::continue::
	end
	-- reschedule detection

end

local anti_radiation_launch = {}												
function anti_radiation_launch:onEvent(event)
    if event.id == world.event.S_EVENT_SHOT then
        local weapon = event.weapon
        if SSF.Sam.isSEADMissile(weapon:getTypeName()) then
            local text = "SEAD missile launched: " .. weapon:getTypeName()
            SSF.Logger:info(text)
            --mist.scheduleFunction(detect_sead_missile, {}, timer.getTime() + 1, 10, timer.getTime()+300)
			timer.scheduleFunction(detect_sead_missile, weapon, timer.getTime() + 1)
        end
    end
end

local function defense_strategy_from_name(name)
	if not name then
		return SSF.Sam.DefenseStrategy.NONE
	end
	name = string.lower(name)
	if name == "turn_off" then
		return SSF.Sam.DefenseStrategy.TURN_OFF
	elseif name == "turn_off_evade" then
		return SSF.Sam.DefenseStrategy.TURN_OFF_EVADE
	else
		return SSF.Sam.DefenseStrategy.NONE
	end
end

local function initialize_sam_defense()
	SSF.Sam.Defend.sam_detect_t = SSF.Properties.Config.sam_detect_t or 10  -- Default detection interval in seconds.
	SSF.Logger:info("SAM detection interval set to " .. SSF.Sam.Defend.sam_detect_t .. " seconds.")
	SSF.Logger:info("initializing SAM groups ...")
	-- iterate through SSF.Properties.UnitProperties to find SAM groups with defense configurations
	for group_name, properties in pairs(SSF.Properties.UnitProperties) do
		SSF.Logger:info("Checking group: " .. group_name .. ":" .. mist.utils.tableShow(properties))
		-- no need to check for ssf property, already done during properties loading
		local group = Group.getByName(group_name)
		if not group then
			SSF.Logger:error("No group found with name: " .. group_name)
			goto continue
		end
		if properties.sam_defense then
			SSF.Logger:info("Configuring SAM defense for group: " .. group_name)
			-- complete configuration with defaults
			local config = {
				active = true,
				defense_strategy = defense_strategy_from_name(properties.sam_defense),
				detection_chance = tonumber(properties.sam_detect_p) or 1.0,
				shutdown_time = tonumber(properties.sam_shutdown_time) or 300,
				range = tonumber(properties.sam_range) or 1.0,
				point_defense = properties.pd_group or "",
				point_defense_active_time = tonumber(properties.pd_active_time) or 600,
			}
			SSF.Logger:info("SAM defense config for " .. group_name .. ": " .. mist.utils.tableShow(config))
			SSF.Sam.Defend[group_name] = config
			-- disable pd_group emissions initially
			-- emit error if pd_group not found and clear config.point_defense
			if config.point_defense and config.point_defense ~= "" then
				local pd_group = Group.getByName(config.point_defense)
				if not pd_group then
					SSF.Logger:error("No point defense group found with name: " .. config.point_defense)
					config.point_defense = ""
				else
					SSF.Logger:info("Disabling emissions for point defense group: " .. config.point_defense)
					SSF.Sam.enableEmissions(config.point_defense, false)
				end
			end
		end
		::continue::
	end
end

SSF.Logger:msg("Loading SAM module...")
initialize_sam_defense()
SSF.Sam.applyRangeRestrictionToAll()
world.addEventHandler(anti_radiation_launch)

