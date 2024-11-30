-- radioControl.lua

-- [Stations and Peripheral setup remain unchanged]

-- Functions

local function drawInterface()
    -- [Unchanged]
end

local function playStation(station)
    -- [Unchanged until the streamingThread creation]
    streamingThread = coroutine.create(function()
        streamAudio(station.url)
    end)
    print("Starting streaming thread for station:", station.name)
    coroutine.resume(streamingThread)
    drawInterface()
end

local function stopPlaying()
    if isPlaying then
        print("Stopping playback...")
        -- [Rest remains unchanged]
    end
end

local function handleMonitorTouch(x, y)
    -- [Unchanged]
end

local function promptForURL()
    -- [Unchanged]
end

local function streamAudio(stream_url)
    -- Import the DFPWM module
    local dfpwm = require("cc.audio.dfpwm")
    
    -- Find all speakers
    local speakers = { peripheral.find("speaker") }
    if #speakers == 0 then
        print("No speakers found.")
        return
    end
    print("Speakers found:", #speakers)
    
    -- Use provided server_ip:port or default to localhost:8765
    local server_ip_port = "localhost:8765"  -- Adjust as needed
    local url = "ws://" .. server_ip_port
    
    print("Attempting to connect to WebSocket server at " .. url)

    -- Connect to the server
    local ws, err = http.websocket(url)
    if not ws then
        print("Failed to connect to WebSocket server:", err)
        return
    end

    print("Connected to WebSocket server.")

    -- Send the stream URL to the server
    local request = { stream_url = stream_url }
    ws.send(textutils.serializeJSON(request))
    print("Sent stream URL to server:", stream_url)
    
    local audioBuffer = {}
    local BUFFER_SIZE = 10  -- Adjust buffer size as needed
    
    -- Create a DFPWM decoder
    local decoder = dfpwm.make_decoder()
    
    -- Function to play audio to all speakers
    local function playToSpeakers(data)
        local pending = {}
        for _, speaker in ipairs(speakers) do
            pending[speaker] = data
        end
        while next(pending) and running do
            for speaker, data in pairs(pending) do
                if speaker.playAudio(data) then
                    pending[speaker] = nil
                end
            end
            if next(pending) then
                os.pullEvent("speaker_audio_empty")
            end
        end
    end
    
    -- Function to play audio from the buffer
    local function playAudio()
        while running do
            if #audioBuffer > 0 then
                print("Playing audio. Buffer size:", #audioBuffer)
                local data = table.remove(audioBuffer, 1)
                -- Decode the DFPWM data
                local success, decoded_or_error = pcall(decoder, data)
                if success then
                    local decoded = decoded_or_error
                    -- Play the decoded audio
                    local play_success, play_err = pcall(function()
                        playToSpeakers(decoded)
                    end)
                    if not play_success then
                        print("Error playing audio:", play_err)
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
                print("Received audio data chunk.")
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
    
    -- Start playing audio and receiving data in parallel
    print("Starting audio playback...")
    parallel.waitForAny(playAudio, receiveAudio)
    
    print("Audio playback ended.")
    -- Ensure the WebSocket is closed
    if ws and not ws.isClosed() then
        ws.close()
    end
end

-- Main Program
drawInterface()

-- Event Loop
while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    handleMonitorTouch(x, y)
end
