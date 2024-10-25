local ws, error = http.websocket("ws://127.0.0.1:8000")

if ws then
    while true do
        local message = ws.receive()
        if message then
            -- Execute the received command and capture output
            local function capture()
                local s = {}
                local old = term.redirect(term.native())
                local result, err = pcall(load(message))
                if not result then
                    table.insert(s, err)
                end
                term.redirect(old)
                return table.concat(s, "\n")
            end

            -- Send the output back through the websocket
            ws.send(capture())
        else
            -- If no message, break the loop and close the connection
            break
        end
    end
    ws.close()
else
    print("Failed to connect: " .. error)
end
