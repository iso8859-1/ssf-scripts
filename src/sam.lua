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

local anti_radiation_launch = {}												
function anti_radiation_launch:onEvent(event)
    if event.id == world.event.S_EVENT_SHOT then
        local weapon = event.weapon
        if SSF.Sam.isSEADMissile(weapon:getTypeName()) then
            local text = "SEAD missile launched: " .. mist.utils.tableShow(weapon:getDesc())
            SSF.Logger:info(text)
        end
    end
end
world.addEventHandler(anti_radiation_launch)