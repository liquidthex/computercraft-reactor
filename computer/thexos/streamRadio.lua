-- Import the DFPWM module
local dfpwm = require("cc.audio.dfpwm")

-- Find all speakers
local speakers = { peripheral.find("speaker") }
if #speakers == 0 then
    print("No speakers found.")
    return
end

-- Get command-line arguments
local args = {...}

-- Check if the stream URL is provided
if #args < 1 then
    print("Usage: streamRadio <stream_url> [server_ip:port]")
    return
end

local stream_url = args[1]

-- Use provided server_ip:port or default to localhost:8765
local server_ip_port = args[2] or "localhost:8765"
local url = "ws://" .. server_ip_port

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

-- Create a DFPWM decoder
local decoder = dfpwm.make_decoder()

-- Variable to control the main loop
local running = true

-- Function to play audio to all speakers with synchronization
local function playAudio()
    while running do
        if #audioBuffer > 0 then
            local data = table.remove(audioBuffer, 1)
            -- Decode the DFPWM data
            local success, decoded_or_error = pcall(decoder, data)
            if success then
                local decoded = decoded_or_error
                -- Break the decoded data into small chunks
                local chunkSize = 8192  -- Adjust chunk size as needed
                local dataLength = #decoded
                for i = 1, dataLength, chunkSize do
                    local chunk = decoded:sub(i, i + chunkSize - 1)
                    -- Wait until all speakers are ready
                    local allSpeakersReady = false
                    while not allSpeakersReady do
                        allSpeakersReady = true
                        for _, speaker in ipairs(speakers) do
                            if speaker.getAudioBufferSize() > 0.1 then
                                allSpeakersReady = false
                                break
                            end
                        end
                        if not allSpeakersReady then
                            os.pullEvent("speaker_audio_empty")
                        end
                    end
                    -- Now play the chunk to all speakers
                    for _, speaker in ipairs(speakers) do
                        speaker.playAudio(chunk)
                    end
                end
            else
                print("Error decoding audio:", decoded_or_error)
            end
        else
            os.sleep(0.05)
        end
    end
end

-- Function to receive audio data
local function receiveAudio()
    while running do
        local data, err = ws.receive()
        if data then
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
            running = false
            break
        end
    end
end

-- Function to handle termination (Ctrl + T)
local function handleTerminate()
    os.pullEvent("terminate")
    print("Terminating...")
    running = false
    -- Close the WebSocket connection
    if ws then
        ws.close()
    end
    -- Stop all speakers
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
end

print("Starting audio playback...")
parallel.waitForAny(playAudio, receiveAudio, handleTerminate)

print("Audio playback ended.")
-- Ensure the WebSocket is closed
if ws and not ws.isClosed() then
    ws.close()
end
-- Stop all speakers
for _, speaker in ipairs(speakers) do
    speaker.stop()
end
