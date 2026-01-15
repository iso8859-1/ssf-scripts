SSF.Sam = SSF.Sam or {}
SSF.Logger:msg("Loading SAM module...")
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
		SSF.Logger:error("Invalid SAM group provided to enableEmissions - " .. mist.utils.tableShow(sam_group))
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
world.addEventHandler(anti_radiation_launch)