local speaker = peripheral.find("speaker")
if not speaker then
    print("Speaker not found.")
    return
end

-- Replace with your server's IP address and port
local server_ip = "your_server_ip"
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

-- Function to convert string data to a table of numbers
local function stringToByteTable(s)
    local t = {}
    for i = 1, #s do
        local byte = string.byte(s, i)
        -- Convert unsigned byte to signed
        if byte >= 128 then
            byte = byte - 256
        end
        table.insert(t, byte)
    end
    return t
end

-- Function to play audio from the buffer
local function playAudio()
    while true do
        if #audioBuffer > 0 then
            local data = table.remove(audioBuffer, 1)
            print("Playing audio chunk")
            local audioData = stringToByteTable(data)
            local success, err = pcall(function()
                speaker.playAudio(audioData, 1)  -- Play at normal volume
            end)
            if not success then
                print("Error playing audio:", err)
            end
        else
            os.sleep(0.05)
        end
    end
end

-- Function to receive audio data
local function receiveAudio()
    while true do
        local data, err = ws.receive()
        if data then
            print("Received data chunk")
            table.insert(audioBuffer, data)
            -- Keep buffer from growing indefinitely
            if #audioBuffer > BUFFER_SIZE then
                table.remove(audioBuffer, 1)
            end
        else
            if err then
                print("WebSocket receive error:", err)
            else
                print("WebSocket closed by server.")
            end
            break
        end
    end
end

print("Starting audio playback...")
parallel.waitForAny(playAudio, receiveAudio)

print("Audio playback ended.")
ws.close()
