-- startup.lua
-- This script runs the update script on startup

-- Check if update.lua exists
if fs.exists("update.lua") then
    shell.run("update.lua")
else
    print("update.lua not found. Skipping update.")
end

-- Run the computerHello.lua script
if fs.exists("computer.lua") then
    shell.run("computer.lua")
else
    print("computer.lua not found.")
end

-- Run the monitorHello.lua script
if fs.exists("monitor.lua") then
    shell.run("monitor.lua")
else
    print("monitor.lua not found.")
end
