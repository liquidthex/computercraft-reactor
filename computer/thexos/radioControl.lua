-- radioControl.lua

-- Table of predefined stations
local stations = {
    {name = "Wefunk", url = "http://s-00.wefunkradio.com:81/wefunk64.mp3"},
    {name = "Groove Salad", url = "https://ice4.somafm.com/groovesalad-128-mp3"},
    {name = "DEFCON Radio", url = "https://ice5.somafm.com/defcon-128-mp3"},
    -- Add or remove stations here
}

-- Peripheral setup
local monitor = peripheral.find("monitor")
if not monitor then
    error("Monitor not found!")
end
monitor.setTextScale(0.5)
local monWidth, monHeight = monitor.getSize()

-- Variables
local isPlaying = false
local currentStation = nil
local running = false
local interfaceLocked = false -- Variable to lock the interface during station change

-- Functions

-- ASCII Art for "STEREO"
local stereoArt = {
" (           (    (       )   ",
" )\\ )   (    )\\ ) )\\ ) ( /(   ",
"(()/(   )\\  (()/((()/( )\\())  ",
" /(_)|(((_)( /(_))/(_)|(_)\\   ",
"(_))  )\\ _ )(_))_(_))   ((_)  ",
"| _ \\ (_)_\\(_)   \\_ _| / _ \\  ",
"|   /  / _ \\ | |) | | | (_) | ",
"|_|_\\ /_/ \\_\\|___/___| \\___/  ",
}

local function centerText(y, text)
    local x = math.floor((monWidth - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function drawInterface()
    monitor.clear()
    monitor.setTextColor(colors.white)
    -- Draw the ASCII art centered
    local artStartY = 2
    for i, line in ipairs(stereoArt) do
        centerText(artStartY + i - 1, line)
    end

    -- Update the status centered under the graphic
    local statusY = artStartY + #stereoArt + 1
    local statusMessage = ""
    local statusColor = colors.white
    if isPlaying then
        statusMessage = "Playing - " .. currentStation.name
        statusColor = colors.green
    elseif interfaceLocked then
        statusMessage = "Changing Stations..."
        statusColor = colors.yellow
    else
        statusMessage = "Stopped"
        statusColor = colors.red
    end

    -- Draw the status in a bubble
    monitor.setTextColor(statusColor)
    centerText(statusY, "[" .. statusMessage .. "]")
    monitor.setTextColor(colors.white)

    -- Draw station buttons larger and graphical
    local buttonStartY = statusY + 2
    local buttonHeight = 3
    local buttonWidth = monWidth - 4 -- Padding on sides

    for i, station in ipairs(stations) do
        local buttonY = buttonStartY + (i - 1) * (buttonHeight + 1)
        -- Draw button background
        monitor.setBackgroundColor(colors.gray)
        for yOffset = 0, buttonHeight - 1 do
            monitor.setCursorPos(3, buttonY + yOffset)
            monitor.write(string.rep(" ", buttonWidth))
        end
        -- Write station name centered
        monitor.setTextColor(colors.white)
        local nameX = math.floor((monWidth - #station.name) / 2) + 1
        local nameY = buttonY + math.floor(buttonHeight / 2)
        monitor.setCursorPos(nameX, nameY)
        monitor.write(station.name)
        monitor.setBackgroundColor(colors.black)
    end

    -- Draw Stop button differently (e.g., in red)
    local stopButtonY = buttonStartY + #stations * (buttonHeight + 1)
    -- Draw button background
    monitor.setBackgroundColor(colors.red)
    for yOffset = 0, buttonHeight - 1 do
        monitor.setCursorPos(3, stopButtonY + yOffset)
        monitor.write(string.rep(" ", buttonWidth))
    end
    -- Write "STOP" centered
    monitor.setTextColor(colors.white)
    local stopText = "STOP"
    local stopX = math.floor((monWidth - #stopText) / 2) + 1
    local stopY = stopButtonY + math.floor(buttonHeight / 2)
    monitor.setCursorPos(stopX, stopY)
    monitor.write(stopText)
    monitor.setBackgroundColor(colors.black)
end

local function playStation(station)
    if isPlaying then
        running = false
        isPlaying = false
        currentStation = nil
        -- Update the status to "Changing Stations..." in yellow
        interfaceLocked = true -- Lock the interface
        drawInterface()
        -- Wait for 5 seconds
        os.sleep(5)
    end
    currentStation = station
    isPlaying = true
    running = true
    interfaceLocked = false -- Unlock the interface
    drawInterface()
end

local function stopPlaying()
    if isPlaying then
        running = false
        isPlaying = false
        currentStation = nil
        drawInterface()
    end
end

local function handleMonitorTouch(x, y)
    if interfaceLocked then
        -- Ignore touch events when interface is locked
        return
    end
    -- Calculate which button was pressed
    local buttonStartY = 2 + #stereoArt + 1 + 2
    local buttonHeight = 3
    local totalButtons = #stations + 1 -- Including Stop button

    for i = 1, totalButtons do
        local buttonY = buttonStartY + (i - 1) * (buttonHeight + 1)
        if y >= buttonY and y < buttonY + buttonHeight then
            if i <= #stations then
                playStation(stations[i])
            else
                stopPlaying()
            end
            break
        end
    end
end

local function urlInputLoop()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        term.write("Custom Radio URL:\n")
        local url = read()
        if url and url ~= "" then
            local customStation = {name = "Custom URL", url = url}
            playStation(customStation)
        end
        -- Wait a bit before prompting again
        os.sleep(0.1)
    end
end

local function streamAudio()
    while true do
        if running and currentStation then
            -- Import the DFPWM module
            local dfpwm = require("cc.audio.dfpwm")
            
            -- Find all speakers
            local speakers = { peripheral.find("speaker") }
            if #speakers == 0 then
                print("No speakers found.")
                running = false
                isPlaying = false
                currentStation = nil
                drawInterface()
                return
            end
            
            -- Use provided server_ip:port or default to localhost:8765
            local server_ip_port = "localhost:8765"  -- Adjust as needed
            local url = "ws://" .. server_ip_port
            
            -- Connect to the server
            local ws, err = http.websocket(url)
            if not ws then
                print("Failed to connect to WebSocket server:", err)
                running = false
                isPlaying = false
                currentStation = nil
                drawInterface()
                return
            end
            
            -- Send the stream URL to the server
            local request = { stream_url = currentStation.url }
            ws.send(textutils.serializeJSON(request))
            
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
            parallel.waitForAny(playAudio, receiveAudio)
            
            -- Ensure the WebSocket is closed
            if ws then
                ws.close()
            end
            
            -- If streaming stopped, reset variables
            if running == false then
                isPlaying = false
                currentStation = nil
                drawInterface()
            end
        else
            os.sleep(0.1)
        end
    end
end

-- Main Program
term.clear()
term.setCursorPos(1, 1)
drawInterface()

-- Event Loop
local function eventLoop()
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        if event == "monitor_touch" then
            handleMonitorTouch(param2, param3)
        end
    end
end

-- Run the event loop, streaming, and URL input loop in parallel
parallel.waitForAny(eventLoop, streamAudio, urlInputLoop)
