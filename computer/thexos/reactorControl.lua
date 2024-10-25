-- reactorControl.lua
-- Script to control and monitor the reactor, with multiple displays and automation

-- Peripheral detection
local reactor = peripheral.find("fissionReactorLogicAdapter")
if not reactor then
    error("Fission Reactor Logic Adapter not found!")
end

-- local inductionPort = peripheral.find("inductionPort")
-- if not inductionPort then
--     print("Warning: Induction Port not found. Energy storage monitoring will be unavailable.")
-- end

-- Find all monitors
local monitorNames = {}
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        table.insert(monitorNames, name)
    end
end

if #monitorNames == 0 then
    error("No monitors found!")
end

-- Load or create the monitor mapping
local function loadMonitorMapping()
    if fs.exists("reactorMap.lua") then
        local mapping = dofile("reactorMap.lua")
        return mapping
    else
        -- Create a default mapping
        local defaultMapping = {}
        for i, name in ipairs(monitorNames) do
            -- Assign default display types in order
            local displayType = ""
            if i == 1 then
                displayType = "reactorStatus"
            elseif i == 2 then
                displayType = "automationControl"
            elseif i == 3 then
                displayType = "energyStorage"
            elseif i == 4 then
                displayType = "eventLog"
            else
                displayType = "unknown"
            end
            defaultMapping[name] = displayType
        end
        -- Save the default mapping
        local file = fs.open("reactorMap.lua", "w")
        file.write("return " .. textutils.serialize(defaultMapping))
        file.close()
        return defaultMapping
    end
end

local monitorMapping = loadMonitorMapping()

-- State definitions
local STATE_GREEN = "GREEN"
local STATE_YELLOW = "YELLOW"
local STATE_RED = "RED"
local STATE_BLACK = "BLACK"

local currentState = STATE_GREEN
local lastStateChangeTime = os.clock()
local statusMessage = "All conditions OK"

-- Event log
local eventLog = {}

local function logEvent(state, message)
    local timestamp = os.time()
    table.insert(eventLog, {
        time = timestamp,
        state = state,
        message = message
    })
    -- Keep only the last 5 events
    while #eventLog > 5 do
        table.remove(eventLog, 1)
    end
end

-- Format time ago
local function formatTimeAgo(time)
    local timeAgo = os.time() - time
    if timeAgo >= 3600 then
        return string.format("%dh ago", math.floor(timeAgo / 3600))
    elseif timeAgo >= 60 then
        return string.format("%dm ago", math.floor(timeAgo / 60))
    else
        return string.format("%ds ago", timeAgo)
    end
end

-- Function to update the reactor state
local function updateState()
    local newState = STATE_GREEN
    local newStatusMessage = "All conditions OK"

    -- Check for manual override (black status)
    if fs.exists("black_status.lock") then
        newState = STATE_BLACK
        newStatusMessage = "Reactor manually disabled"
    end

    -- Check reactor readiness
    if reactor.getDamagePercent() > 0 then
        newState = STATE_BLACK
        newStatusMessage = "Reactor damaged"
    elseif reactor.isForceDisabled() then
        newState = STATE_BLACK
        newStatusMessage = "Reactor cannot run (e.g., out of fuel)"
    end

    -- Check red conditions (only if not black)
    if newState ~= STATE_BLACK then
        if reactor.getCoolantFilledPercentage() < 0.9 then
            newState = STATE_RED
            newStatusMessage = "Coolant below 90% full"
        elseif reactor.getWasteFilledPercentage() > 0.1 then
            newState = STATE_RED
            newStatusMessage = "Waste above 10% full"
        elseif peripheral.find("inductionPort") and peripheral.find("inductionPort").getEnergyFilledPercentage() > 0.8 then
            newState = STATE_RED
            newStatusMessage = "Energy storage more than 80% full"
        end
    end

    -- Check yellow conditions (only if green)
    if newState == STATE_GREEN then
        if not peripheral.find("inductionPort") then
            newState = STATE_YELLOW
            newStatusMessage = "No response from energy storage modem"
        elseif reactor.getFuelFilledPercentage() < 1.0 then
            newState = STATE_YELLOW
            newStatusMessage = "Fuel below 100% full"
        end
    end

    -- Enforce delay before returning to green from red
    if currentState == STATE_RED and newState == STATE_GREEN then
        local timeSinceRed = os.clock() - lastStateChangeTime
        if timeSinceRed < 30 then
            newState = STATE_RED
            newStatusMessage = "Waiting for conditions to stabilize"
        end
    end

    -- Handle state transitions
    if newState ~= currentState then
        lastStateChangeTime = os.clock()
        logEvent(newState, newStatusMessage)
    end

    currentState = newState
    statusMessage = newStatusMessage
end

-- Function to control the reactor based on state
local function controlReactor()
    if currentState == STATE_GREEN or currentState == STATE_YELLOW then
        if not reactor.getStatus() then
            reactor.activate()
            print("Reactor activated.")
        end
    elseif currentState == STATE_RED or currentState == STATE_BLACK then
        if reactor.getStatus() then
            reactor.scram()
            print("Reactor scrammed.")
        end
    end
end

-- Function to convert Joules to FE (Forge Energy)
local function joulesToFE(joules)
    return mekanismEnergyHelper.joulesToFE(joules)
end

-- Function to get energy storage info
local function getEnergyStorageInfo()
    if not peripheral.find("inductionPort") then
        print("Induction Port is not available.")
        return nil
    end
    print("here4")
    local energyFilledPercentage = peripheral.find("inductionPort").getEnergyFilledPercentage()
    print("here5")
    local energy = peripheral.find("inductionPort").getEnergy()
    print("here6")
    local maxEnergy = inductiperipheral.find("inductionPort")onPort.getMaxEnergy()
    print("here7")
    local lastInput = peripheral.find("inductionPort").getLastInput()
    print("here8")
    local lastOutput = peripheral.find("inductionPort").getLastOutput()
    print("here9")
    -- Convert Joules to FE
    energy = joulesToFE(energy)
    maxEnergy = joulesToFE(maxEnergy)
    lastInput = joulesToFE(lastInput)
    lastOutput = joulesToFE(lastOutput)
    print("here10")

    -- Log values to console for debugging
    print("Energy Filled Percentage: " .. energyFilledPercentage)
    print("Energy: " .. energy)
    print("Max Energy: " .. maxEnergy)
    print("Last Input: " .. lastInput)
    print("Last Output: " .. lastOutput)

    return {
        energyFilledPercentage = energyFilledPercentage,
        energy = energy,
        maxEnergy = maxEnergy,
        lastInput = lastInput,
        lastOutput = lastOutput
    }
end

-- Function to format large numbers
local function formatLargeNumber(number)
    local units = {"", "K", "M", "G", "T", "P", "E"}
    local index = 1
    while number >= 1000 and index < #units do
        number = number / 1000
        index = index + 1
    end
    return string.format("%.2f %s", number, units[index])
end

-- Display functions
local monitorFunctions = {}

-- Display 1: Reactor Status Display
monitorFunctions["reactorStatus"] = function(monitor)
    while true do
        monitor.clear()
        monitor.setCursorPos(1,1)
        monitor.setTextScale(0.5)
        local width, height = monitor.getSize()

        -- Get reactor status
        local status = reactor.getStatus()
        local temperatureK = reactor.getTemperature()
        local temperatureC = temperatureK - 273.15
        local damagePercent = reactor.getDamagePercent() * 100
        local coolantPercent = reactor.getCoolantFilledPercentage() * 100
        local fuelPercent = reactor.getFuelFilledPercentage() * 100
        local wastePercent = reactor.getWasteFilledPercentage() * 100
        local burnRate = reactor.getBurnRate()
        local actualBurnRate = reactor.getActualBurnRate()
        local maxBurnRate = reactor.getMaxBurnRate()

        -- Display reactor information
        monitor.setTextColor(colors.yellow)
        monitor.write("Mekanism Fission Reactor")
        monitor.setCursorPos(1,2)
        monitor.setTextColor(colors.white)

        monitor.write("Status: ")
        if status then
            monitor.setTextColor(colors.green)
            monitor.write("Active")
        else
            monitor.setTextColor(colors.red)
            monitor.write("Inactive")
        end

        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1,3)
        monitor.write("Temperature: ")
        if temperatureC < 1000 then
            monitor.setTextColor(colors.green)
        else
            monitor.setTextColor(colors.red)
        end
        monitor.write(string.format("%.2f C", temperatureC))

        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1,4)
        monitor.write("Damage: ")
        if damagePercent == 0 then
            monitor.setTextColor(colors.green)
        else
            monitor.setTextColor(colors.red)
        end
        monitor.write(string.format("%.2f%%", damagePercent))

        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1,5)
        monitor.write("")

        monitor.write("Coolant:")
        monitor.setCursorPos(1,6)
        monitor.write(" - Filled: ")
        if coolantPercent > 90 then
            monitor.setTextColor(colors.green)
        else
            monitor.setTextColor(colors.red)
        end
        monitor.write(string.format("%.2f%%", coolantPercent))

        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1,7)
        monitor.write("Fuel:")
        monitor.setCursorPos(1,8)
        monitor.write(" - Filled: ")
        if fuelPercent == 100 then
            monitor.setTextColor(colors.green)
        else
            monitor.setTextColor(colors.yellow)
        end
        monitor.write(string.format("%.2f%%", fuelPercent))

        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1,9)
        monitor.write("Waste:")
        monitor.setCursorPos(1,10)
        monitor.write(" - Filled: ")
        if wastePercent < 10 then
            monitor.setTextColor(colors.green)
        else
            monitor.setTextColor(colors.red)
        end
        monitor.write(string.format("%.2f%%", wastePercent))

        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1,11)
        monitor.write(string.format("Burn Rate: %.2f mB/t", burnRate))
        monitor.setCursorPos(1,12)
        monitor.write(string.format("Actual Burn Rate: %.2f mB/t", actualBurnRate))
        monitor.setCursorPos(1,13)
        monitor.write(string.format("Max Burn Rate: %.2f mB/t", maxBurnRate))

        sleep(1)
    end
end

-- Display 2: Automation Control Screen
monitorFunctions["automationControl"] = function(monitor)
    -- Implementing a simple button API inline
    local buttons = {}
    local function addButton(label, func, xmin, ymin, xmax, ymax, bgColor, textColor)
        buttons[#buttons + 1] = {
            label = label,
            func = func,
            xmin = xmin,
            ymin = ymin,
            xmax = xmax,
            ymax = ymax,
            bgColor = bgColor,
            textColor = textColor
        }
    end

    local function drawButtons()
        for _, button in ipairs(buttons) do
            monitor.setBackgroundColor(button.bgColor)
            monitor.setTextColor(button.textColor)
            for y = button.ymin, button.ymax do
                monitor.setCursorPos(button.xmin, y)
                monitor.write(string.rep(" ", button.xmax - button.xmin + 1))
            end
            local labelX = math.floor((button.xmin + button.xmax - #button.label) / 2)
            local labelY = math.floor((button.ymin + button.ymax) / 2)
            monitor.setCursorPos(labelX, labelY)
            monitor.write(button.label)
        end
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)
    end

    local function handleClick(x, y)
        for _, button in ipairs(buttons) do
            if x >= button.xmin and x <= button.xmax and y >= button.ymin and y <= button.ymax then
                button.func()
                return
            end
        end
    end

    monitor.setTextScale(0.5)
    monitor.clear()

    -- Define buttons
    addButton("Shutdown", function()
        -- Create a lock file to trigger black status
        local file = fs.open("black_status.lock", "w")
        file.close()
        print("Manual shutdown initiated.")
    end, 2, 2, 15, 4, colors.red, colors.white)

    addButton("Startup", function()
        -- Remove the lock file
        if fs.exists("black_status.lock") then
            fs.delete("black_status.lock")
            print("Manual startup initiated.")
        end
    end, 18, 2, 31, 4, colors.green, colors.white)

    -- Main loop for the automation control screen
    while true do
        monitor.clear()
        drawButtons()

        -- Display current status
        monitor.setCursorPos(2,6)
        monitor.write("Status: ")
        if currentState == STATE_GREEN then
            monitor.setTextColor(colors.green)
        elseif currentState == STATE_YELLOW then
            monitor.setTextColor(colors.yellow)
        elseif currentState == STATE_RED then
            monitor.setTextColor(colors.red)
        elseif currentState == STATE_BLACK then
            monitor.setTextColor(colors.gray)
        end
        monitor.write(currentState)
        monitor.setTextColor(colors.white)

        monitor.setCursorPos(2,7)
        monitor.write("Message: " .. statusMessage)

        -- Handle touch events
        local event, side, x, y = os.pullEvent()
        if event == "monitor_touch" then
            handleClick(x, y)
        end
        sleep(0.1)
    end
end

-- Display 3: Energy Storage Information
monitorFunctions["energyStorage"] = function(monitor)
    monitor.setTextScale(0.5)
    while true do
        monitor.clear()
        monitor.setCursorPos(1,1)

        if not peripheral.find("inductionPort") then
            monitor.setTextColor(colors.red)
            monitor.write("Induction Port not connected.")
            sleep(5)
            break
        end

        local energyInfo = getEnergyStorageInfo()
        if not energyInfo then
            monitor.setTextColor(colors.red)
            monitor.write("Failed to retrieve energy info.")
            sleep(5)
            break
        end

        --Display energy bar
        local barHeight = 20
        local barWidth = 4
        local filledHeight = math.floor(barHeight * energyInfo.energyFilledPercentage)
        for y = 1, barHeight do
            monitor.setCursorPos(2, barHeight - y + 2)
            if y <= filledHeight then
                monitor.setBackgroundColor(colors.green)
            else
                monitor.setBackgroundColor(colors.gray)
            end
            monitor.write(string.rep(" ", barWidth))
        end
        monitor.setBackgroundColor(colors.black)

        --Display labels
        monitor.setCursorPos(7, 2)
        monitor.write("Energy Storage")
        monitor.setCursorPos(7, 4)
        monitor.write("Level: " .. string.format("%.2f%%", energyInfo.energyFilledPercentage * 100))

        monitor.setCursorPos(7, 6)
        monitor.write("Input: " .. formatLargeNumber(energyInfo.lastInput) .. " FE/t")
        monitor.setCursorPos(7, 7)
        monitor.write("Output: " .. formatLargeNumber(energyInfo.lastOutput) .. " FE/t")

        monitor.setCursorPos(7, 9)
        monitor.write("Total: " .. formatLargeNumber(energyInfo.energy) .. " FE")
        monitor.setCursorPos(7, 10)
        monitor.write("Capacity: " .. formatLargeNumber(energyInfo.maxEnergy) .. " FE")

        sleep(1)
    end
end

-- Display 4: Event Log
monitorFunctions["eventLog"] = function(monitor)
    monitor.setTextScale(0.5)
    while true do
        monitor.clear()
        monitor.setCursorPos(1,1)
        monitor.write("Event Log")

        local y = 3
        for i = #eventLog, 1, -1 do
            local event = eventLog[i]
            monitor.setCursorPos(1, y)
            monitor.write(formatTimeAgo(event.time) .. " - " .. event.state .. " - " .. event.message)
            y = y + 1
        end
        sleep(5)
    end
end

-- Function to start display functions in parallel
local function startDisplays()
    local displayThreads = {}
    for name, displayType in pairs(monitorMapping) do
        local monitor = peripheral.wrap(name)
        if monitor and monitorFunctions[displayType] then
            print("Launching " .. displayType .. " on monitor " .. name)
            print(peripheral.find("inductionPort").getEnergyFilledPercentage())
            displayThreads[#displayThreads + 1] = function()
                monitorFunctions[displayType](monitor)
            end
        else
            print("Monitor " .. name .. " has unknown display type: " .. displayType)
        end
    end
    -- Start all displays in parallel
    parallel.waitForAll(table.unpack(displayThreads))
end

-- Main function
local function main()
    -- Start displays in background
    local displayThread = coroutine.create(startDisplays)

    -- Main loop
    while true do
        updateState()
        controlReactor()
        sleep(1)
        -- Resume display thread if needed
        if coroutine.status(displayThread) == "suspended" then
            local ok, err = coroutine.resume(displayThread)
            if not ok then
                print("Error in coroutine:", err)
            end
        end
    end
end

-- Auto-restart logic
while true do
    local success, errorMessage = pcall(main)
    if not success then
        print("Reactor Control script crashed: " .. errorMessage)
        print("Restarting in 5 seconds...")
        sleep(5)
    else
        break -- Exit the loop if main() completes successfully
    end
end
