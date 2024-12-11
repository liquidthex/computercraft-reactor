-- fissionReactorControl.lua

-- Peripheral detection
local reactor = peripheral.find("fissionReactorLogicAdapter")
if not reactor then
    error("Fission Reactor Logic Adapter not found!")
end

local inductionPort = peripheral.find("inductionPort")
if not inductionPort then
    print("Warning: Induction Port not found. Energy storage monitoring will be unavailable.")
end

local monitor = peripheral.find("monitor")
if not monitor then
    error("Monitor not found!")
end

monitor.setTextScale(0.5)
term.redirect(monitor)

-- Function to convert Joules to FE (Forge Energy)
local function joulesToFE(joules)
    if not joules then
        return 0
    end
    return joules * 2.5
end

-- Function to get energy storage info
local function getEnergyStorageInfo()
    if not inductionPort or not inductionPort.getEnergyFilledPercentage then
        print("Induction Port is not available.")
        return nil
    end
    local energyFilledPercentage = inductionPort.getEnergyFilledPercentage()
    local energy = inductionPort.getEnergy()
    local maxEnergy = inductionPort.getMaxEnergy()
    local lastInput = inductionPort.getLastInput()
    local lastOutput = inductionPort.getLastOutput()
    -- Convert Joules to FE
    energy = joulesToFE(energy)
    maxEnergy = joulesToFE(maxEnergy)
    lastInput = joulesToFE(lastInput)
    lastOutput = joulesToFE(lastOutput)

    return {
        energyFilledPercentage = energyFilledPercentage,
        energy = energy,
        maxEnergy = maxEnergy,
        lastInput = lastInput,
        lastOutput = lastOutput
    }
end

local conditionStatus = "Green" -- "Green", "Yellow", "Red", "Black"
local manualShutdown = false
local logEntries = {}
local logFile = "fission_log.txt"

-- Function to load log from file
local function loadLog()
    if fs.exists(logFile) then
        local file = fs.open(logFile, "r")
        logEntries = textutils.unserialize(file.readAll())
        file.close()
    end
    if not logEntries then
        logEntries = {}
    end
end

-- Function to save log to file
local function saveLog()
    local file = fs.open(logFile, "w")
    file.write(textutils.serialize(logEntries))
    file.close()
end

-- Function to add a log entry
local function addLogEntry(timestamp, condition, message)
    table.insert(logEntries, 1, {timestamp = timestamp, condition = condition, message = message})
    while #logEntries > 10 do
        table.remove(logEntries)
    end
    saveLog()
end

-- Function to get reactor info
local function getReactorInfo()
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

    return {
        status = status,
        temperatureK = temperatureK,
        temperatureC = temperatureC,
        damagePercent = damagePercent,
        coolantPercent = coolantPercent,
        fuelPercent = fuelPercent,
        wastePercent = wastePercent,
        burnRate = burnRate,
        actualBurnRate = actualBurnRate,
        maxBurnRate = maxBurnRate
    }
end

-- Function to update reactor status and control logic
local function updateReactorStatus()
    local reactorInfo = getReactorInfo()
    local energyInfo = getEnergyStorageInfo()

    local previousCondition = conditionStatus

    -- Default to Green
    local newCondition = "Green"

    -- Check for Black conditions
    if reactorInfo.coolantPercent < 90 then
        newCondition = "Black"
        manualShutdown = true
        if previousCondition ~= "Black" then
            addLogEntry(os.time(), "Black", "Coolant below 90%")
        end
    elseif reactorInfo.damagePercent > 0 then
        newCondition = "Black"
        manualShutdown = true
        if previousCondition ~= "Black" then
            addLogEntry(os.time(), "Black", "Reactor damaged")
        end
    elseif reactorInfo.wastePercent > 10 then
        newCondition = "Black"
        manualShutdown = true
        if previousCondition ~= "Black" then
            addLogEntry(os.time(), "Black", "Waste above 10%")
        end
    elseif manualShutdown then
        newCondition = "Black"
        if previousCondition ~= "Black" then
            addLogEntry(os.time(), "Black", "Manual shutdown activated")
        end
    end

    -- If not Black, check for Red conditions
    if newCondition == "Green" then
        if reactor.getStatus() == false and not manualShutdown then
            newCondition = "Red"
            if previousCondition ~= "Red" then
                addLogEntry(os.time(), "Red", "Reactor is offline")
            end
        end
    end

    -- If not Black or Red, check for Yellow conditions
    if newCondition == "Green" then
        if reactorInfo.fuelPercent < 50 then
            newCondition = "Yellow"
            if previousCondition ~= "Yellow" then
                addLogEntry(os.time(), "Yellow", "Fuel below 50%")
            end
        elseif energyInfo and energyInfo.energyFilledPercentage > 90 then
            newCondition = "Yellow"
            if previousCondition ~= "Yellow" then
                addLogEntry(os.time(), "Yellow", "Reactor paused due to energy overstock")
            end
        end
    end

    -- Update conditionStatus
    conditionStatus = newCondition

    -- Control the reactor based on condition
    if conditionStatus == "Black" then
        if reactor.getStatus() then
            reactor.scram()
        end
    elseif conditionStatus == "Red" then
        if not reactor.getStatus() and not manualShutdown then
            reactor.activate()
        end
    elseif conditionStatus == "Yellow" then
        if energyInfo and energyInfo.energyFilledPercentage > 90 then
            if reactor.getStatus() then
                reactor.scram()
            end
        elseif energyInfo and energyInfo.energyFilledPercentage < 80 then
            if not reactor.getStatus() and not manualShutdown then
                reactor.activate()
                conditionStatus = "Green"
                if previousCondition ~= "Green" then
                    addLogEntry(os.time(), "Green", "Reactor resumed due to energy understock")
                end
            end
        end
    elseif conditionStatus == "Green" then
        if not reactor.getStatus() and not manualShutdown then
            reactor.activate()
        end
    end
end

-- Function to draw the energy bar
local function drawEnergyBar()
    local w, h = monitor.getSize()
    local energyInfo = getEnergyStorageInfo()
    if not energyInfo then
        return
    end
    local barWidth = w
    local filledWidth = math.floor(energyInfo.energyFilledPercentage * barWidth)
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.gray)
    monitor.clearLine()
    monitor.setBackgroundColor(colors.green)
    monitor.write(string.rep(" ", filledWidth))
    monitor.setBackgroundColor(colors.gray)
    monitor.write(string.rep(" ", barWidth - filledWidth))
    monitor.setCursorPos(1, 2)
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
    local energyStr = string.format("%.1fT / %.1fT", energyInfo.energy / 1e12, energyInfo.maxEnergy / 1e12)
    monitor.clearLine()
    monitor.write(energyStr)
end

-- Function to draw the manual shutdown button
local function drawManualShutdownButton()
    local w, h = monitor.getSize()
    local buttonY = 3
    monitor.setCursorPos(1, buttonY)
    monitor.setTextColor(colors.white)
    if manualShutdown then
        monitor.setBackgroundColor(colors.red)
    else
        monitor.setBackgroundColor(colors.green)
    end
    local buttonLabel = "MANUAL SHUTDOWN"
    monitor.clearLine()
    monitor.write(buttonLabel)
end

-- Function to draw the log
local function drawLog()
    local w, h = monitor.getSize()
    local logYStart = 5
    local maxLogEntries = h - logYStart + 1
    for i = 1, math.min(#logEntries, maxLogEntries) do
        local entry = logEntries[i]
        local y = logYStart + i - 1
        monitor.setCursorPos(1, y)
        monitor.setTextColor(colors.white)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        -- Calculate relative time
        local timeDiff = os.time() - entry.timestamp
        local timeStr = ""
        if timeDiff < 60 then
            timeStr = tostring(timeDiff) .. "s"
        elseif timeDiff < 3600 then
            timeStr = tostring(math.floor(timeDiff / 60)) .. "m"
        else
            timeStr = tostring(math.floor(timeDiff / 3600)) .. "h"
        end

        -- Set color based on condition
        local conditionColor = colors.white
        if entry.condition == "Green" then
            conditionColor = colors.green
        elseif entry.condition == "Yellow" then
            conditionColor = colors.yellow
        elseif entry.condition == "Red" then
            conditionColor = colors.red
        elseif entry.condition == "Black" then
            conditionColor = colors.black
        end

        monitor.setTextColor(colors.white)
        monitor.write(timeStr .. " [")
        monitor.setTextColor(conditionColor)
        monitor.write(entry.condition)
        monitor.setTextColor(colors.white)
        monitor.write("] " .. entry.message)
    end
end

-- Function to handle monitor touch events
local function handleMonitorTouch(event, side, x, y)
    local buttonY = 3
    if y == buttonY then
        manualShutdown = not manualShutdown
        if manualShutdown then
            addLogEntry(os.time(), "Black", "Manual shutdown activated")
        else
            addLogEntry(os.time(), "Green", "Manual shutdown deactivated")
        end
    end
end

-- Load log from file
loadLog()

-- Event handler function
local function eventHandler()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        handleMonitorTouch(event, side, x, y)
    end
end

-- Update loop function
local function updateLoop()
    while true do
        updateReactorStatus()
        monitor.clear()
        drawEnergyBar()
        drawManualShutdownButton()
        drawLog()
        sleep(5)
    end
end

-- Start the parallel threads
parallel.waitForAny(updateLoop, eventHandler)
