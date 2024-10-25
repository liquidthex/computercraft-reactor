-- debug_daemon.lua
local port = 8000  -- Choose an open port for your WebSocket server

-- Start the WebSocket server
print("Starting WebSocket server on port " .. port)
local ws, err = http.websocket("ws://localhost:" .. port)

if not ws then
    error("Failed to start WebSocket server: " .. tostring(err))
end

print("WebSocket server started on port " .. port)

while true do
    -- Wait for incoming messages from the WebSocket client
    local command = ws.receive()

    if command then
        -- Try to execute the received command
        local func, load_err = load(command)
        local response
        if func then
            local success, result = pcall(func)
            if success then
                response = "Result: " .. tostring(result)
            else
                response = "Error executing command: " .. tostring(result)
            end
        else
            response = "Error loading command: " .. tostring(load_err)
        end

        -- Send back the result or error
        ws.send(response)
    end
end
