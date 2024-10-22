-- startup.lua
-- This script runs the update script on startup

-- Check if update.lua exists
if fs.exists("update.lua") then
    shell.run("update.lua")
else
    print("update.lua not found. Skipping update.")
end
