-- Wrap the monitor peripheral on the right side
local monitor = peripheral.wrap("right")

if monitor then
    -- Clear the monitor and set cursor to the top-left corner
    monitor.clear()
    monitor.setCursorPos(1, 1)
    
    -- Set text scale if needed
    monitor.setTextScale(1) -- Adjust this value between 0.5 and 5 as desired
    
    -- Write "Hello, World!" on the monitor
    monitor.write("Hello, World!")
else
    print("No monitor found on the right side.")
end
