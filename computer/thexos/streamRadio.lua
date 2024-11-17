local speaker = peripheral.find("speaker")
if not speaker then
    print("Speaker not found.")
    return
end

-- Replace with your server's IP address and port
local server_ip = "localhost"
local port = 8765
local url = "ws://" .. server_ip .. ":" .. port

-- Function to read user input for stream URL
local function getStreamURL()
    print("Enter the radio stream URL:")
    local stream_url = read()
    return stream_url
end

local stream_url = getStreamURL()

-- Connect to the server
local ws, err = http.websocket(url)
if not ws then
    print("Failed to connect:", err)
    return
end

-- Send the stream URL to the server
local request = { stream_url = stream_url }
ws.send(textutils.serializeJSON(request))

print("Connected to the streaming server.")

local audioBuffer = {}
local BUFFER_SIZE = 10  -- Adjust buffer size as needed

-- Function to play audio from the buffer
local function playAudio()
    while true do
        if #audioBuffer > 0 then
            local data = table.remove(audioBuffer, 1)
            speaker.playAudio(data, 1)  -- Play at normal volume
        else
            os.sleep(0.05)
        end
    end
end

-- Function to receive audio data
local function receiveAudio()
    while true do
        local data = ws.receive()
        if data then
            table.insert(audioBuffer, data)
            -- Keep buffer from growing indefinitely
            if #audioBuffer > BUFFER_SIZE then
                table.remove(audioBuffer, 1)
            end
        else
            break
        end
    end
end

parallel.waitForAny(playAudio, receiveAudio)

ws.close()
