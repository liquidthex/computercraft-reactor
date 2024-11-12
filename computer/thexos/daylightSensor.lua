-- daylightSensor.lua

-- Open rednet on the side where the modem is connected (adjust "left" as needed)
rednet.open("left")

-- Initialize the previous state (nil means uninitialized)
local previousState = nil

while true do
    -- Check the redstone input from the daylight detector (adjust "back" as needed)
    local currentState = redstone.getInput("back")

    -- On the first run, set the previous state
    if previousState == nil then
        previousState = currentState
    end

    -- Detect state change
    if currentState ~= previousState then
        if currentState then
            -- It's day time
            rednet.broadcast("day", "thexos")
            print("Broadcasted: day")
        else
            -- It's night time
            rednet.broadcast("night", "thexos")
            print("Broadcasted: night")
        end
        -- Update the previous state
        previousState = currentState
    end

    -- Wait for 5 seconds before the next check
    sleep(5)
end
