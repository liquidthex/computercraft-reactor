-- Import the DFPWM module
local dfpwm = require("cc.audio.dfpwm")

-- Find all speakers and their peripheral names
local speakerNames = { peripheral.find("speaker") }
if #speakerNames == 0 then
    print("No speakers found.")
    return
end

-- Wrap each speaker peripheral
local speakers = {}
for i, name in ipairs(speakerNames) do
    speakers[name] = peripheral.wrap(name)
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

-- Table to keep track of which speakers are ready
local speakersReady = {}

-- Initialize speakersReady table
for name in pairs(speakers) do
    speakersReady[name] = true  -- Start with true since all speakers are initially ready
end

-- Function to play audio to all speakers with synchronization
local function playAudio()
    while running do
        if #audioBuffer > 0 then
            local data = table.remove(audioBuffer, 1)
            -- Decode the DFPWM data
            local success, decoded_or_error = pcall(decoder, data)
            if success then
                local decoded = decoded_or_error
                -- Convert decoded table to string if necessary
                if type(decoded) == "table" then
                    -- Convert table of numbers to a string
                    local charTable = {}
                    for i = 1, #decoded do
                        -- Map the sample from [-1, 1] to [0, 255]
                        local sample = math.floor((decoded[i] + 1) * 127.5)
                        -- Ensure the sample is within [0, 255]
                        sample = math.max(0, math.min(255, sample))
                        charTable[i] = string.char(sample)
                    end
                    decoded = table.concat(charTable)
                elseif type(decoded) ~= "string" then
                    print("Decoded data is not a string or table. Type:", type(decoded))
                    running = false
                    break
                end

                -- Wait until all speakers are ready
                local allSpeakersReady = false
                while not allSpeakersReady do
                    allSpeakersReady = true
                    for name, ready in pairs(speakersReady) do
                        if not ready then
                            allSpeakersReady = false
                            break
                        end
                    end
                    if not allSpeakersReady then
                        os.pullEvent("speaker_audio_empty")
                    end
                end

                -- Play the decoded audio to all speakers
                for name, speaker in pairs(speakers) do
                    local play_success, play_err = pcall(function()
                        speaker.playAudio(decoded)
                    end)
                    if not play_success then
                        print("Error playing audio on speaker", name, ":", play_err)
                    end
                    -- Mark the speaker as not ready
                    speakersReady[name] = false
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

-- Function to handle speaker events
local function handleSpeakerEvents()
    while running do
        local event, side = os.pullEvent("speaker_audio_empty")
        if speakersReady[side] ~= nil then
            speakersReady[side] = true
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
    for _, speaker in pairs(speakers) do
        speaker.stop()
    end
end

print("Starting audio playback...")
parallel.waitForAny(playAudio, receiveAudio, handleSpeakerEvents, handleTerminate)

print("Audio playback ended.")
-- Ensure the WebSocket is closed
if ws then
    ws.close()
end
-- Stop all speakers
for _, speaker in pairs(speakers) do
    speaker.stop()
end
