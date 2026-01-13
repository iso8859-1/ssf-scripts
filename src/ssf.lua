--[[
Simple Scripting Functions (SSF)
Copyright (C) 2020-2024  Tobias Langner
This program is free software: you can redistribute it and/or modify it under the terms of the BSD-3-Clause license.

Simple Scripting Functions (SSF) is a collection of useful functions and features for DCS World mission makers and scripters.
It is designed to be modular, so you can enable or disable features as needed.

This file is the base module for SSF. It is required by all other SSF modules. It contains the unit-properties system and basic utility functions like logging.
]]

SSF = SSF or {}

--region Logger Utility
--[[
Logging Utility
This utility provides a simple way to log messages with different severity levels.
It uses mist.Logger for logging, which is part of the MIST library.

It provides a special logging mode called "dev" mode. In dev mode, all log messages are written to dcs.log (category "info") and additionally they are
broadcasted as in-game messages to all players. This is useful for debugging during mission development.
]]
SSF.Logger = SSF.Logger or {}

-- Initializes the logger instance.
function SSF.Logger:new()
    local logger = mist.Logger:new("SSF", "info")
    SSF.Logger._logger = logger
    SSF.devMode = false
    return self
end

-- Sets the logging level. If level is "dev", enables dev mode.
function SSF.Logger:setLevel(level)
    if (level == "dev") then
        self._logger:setLevel("info")
        SSF.devMode = true
    else
        self._logger:setLevel(level)
        SSF.devMode = false
    end
end

-- Logs an info message. In dev mode, also broadcasts the message in-game.
function SSF.Logger:info(message)
    self._logger:info(message)
    if SSF.devMode then
        local msg = {}
        msg.text = "[SSF][INFO] " .. message
        msg.displayTime = 10
        msg.msgFor = {coa = {'all'}}
        mist.message.add(msg)
    end
end

-- Logs a warning message. In dev mode, also broadcasts the message in-game.
function SSF.Logger:warning(message)
    self._logger:warning(message)
    if SSF.devMode then
        local msg = {}
        msg.text = "[SSF][WARNING] " .. message
        msg.displayTime = 10
        msg.msgFor = {coa = {'all'}}
        mist.message.add(msg)
    end
end

-- Logs an error message. In dev mode, also broadcasts the message in-game.
function SSF.Logger:error(message)
    self._logger:error(message)
    if SSF.devMode then
        local msg = {}
        msg.text = "[SSF][ERROR] " .. message
        msg.displayTime = 10
        msg.msgFor = {coa = {'all'}}
        mist.message.add(msg)
    end
end

-- Logs a message to log only - regardless of levels.
function SSF.Logger:msg(message)
    self._logger:msg(message)
end
--endregion

--region Properties System
--[[
Properties System
This system allows you to define and manage custom properties for units in DCS World.

UnitProperties is a table where each key is a unit's name and the value is another table containing the properties for that unit.
During mission initialization, you can populate this table with properties from TriggerZone properties. The zone needs to have a property "ssf" and a property "group" with the unit's name as value.

Config is a table for global SSF configuration settings. It contains the initialization settings for the logger and other global options. It can be initalized with a property "ssf_config" in a TriggerZone. The remaining properties will be copied as key-value pairs into the Config table.
]]
SSF.Properties = SSF.Properties or {}
SSF.Properties.UnitProperties = SSF.Properties.UnitProperties or {}
SSF.Properties.Config = SSF.Properties.Config or { logLevel = "error" }  -- Default log level is "error". 

local function _initializeProperties()
    SSF.Logger:msg("Initializing SSF Properties System...")
    -- iterate over all trigger zones to find unit properties
    local zones = mist.DBs.zonesByNum
    for _, zone in pairs(zones) do
        -- Check for unit properties
        if zone.properties and zone.properties.ssf and zone.properties.group then
            local unitName = zone.properties.group
            SSF.Properties.UnitProperties[unitName] = SSF.Properties.UnitProperties[unitName] or {}
            for key, value in pairs(zone.properties) do
                if key ~= "ssf" and key ~= "group" then
                    SSF.Properties.UnitProperties[unitName][key] = value
                    SSF.Logger:info("Set property '" .. key .. "' for unit '" .. unitName .. "' to '" .. tostring(value) .. "'")
                end
            end
        end
        -- Check for global config
        if zone.properties and zone.properties.ssf_config then
            for key, value in pairs(zone.properties) do
                if key ~= "ssf_config" then
                    SSF.Properties.Config[key] = value
                    SSF.Logger:info("Set global config '" .. key .. "' to '" .. tostring(value) .. "'")
                end
            end
        end
    end
end
--endregion

-- create Logger
SSF.Logger:new()
-- read properties from trigger zones
_initializeProperties()
-- reconfigure Logger based on properties
local loglevel = SSF.Properties.Config.logLevel or "error"
SSF.Logger:setLevel(loglevel)
SSF.Logger:info("SSF Logger initialized with level: " .. loglevel)
SSF.Logger:info("SSF Properties System initialized.")