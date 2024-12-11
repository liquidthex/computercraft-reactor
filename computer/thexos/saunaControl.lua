-- Configuration
local monitorSide = "back"   -- Your monitor peripheral name
local redstoneSide = "bottom"
local warmupTime = 60           -- seconds of warmup
local cooldownTime = 15         -- seconds of cooldown
local backgroundColor = colors.black
local buttonColor = colors.gray
local textColor = colors.white
local warmupBarColor = colors.orange
local fullBarColor = colors.lime
local cooldownBarColor = colors.red
local barBackgroundColor = colors.lightGray
local refreshInterval = 0.5     -- update interval for progress bar

-- Times available in minutes
local timeOptions = {2, 5, 10}

-- Wrap peripherals
local mon = peripheral.wrap(monitorSide)
mon.setBackgroundColor(backgroundColor)
mon.setTextColor(textColor)
mon.setTextScale(1)
mon.clear()

-- Get monitor size
local monW, monH = mon.getSize()

local state = "IDLE"
local chosenTime = 0  -- total run time user selected (seconds, includes warmup)
local startTime = 0
local running = false

-- Button definitions: 3 horizontal buttons side by side
local numButtons = #timeOptions
local buttonWidth = math.floor(monW / numButtons)
local buttonHeight = monH
local buttons = {}

for i, t in ipairs(timeOptions) do
    local xStart = (i-1)*buttonWidth + 1
    local xEnd = xStart + buttonWidth - 1
    buttons[i] = {
        x1 = xStart,
        y1 = 1,
        x2 = xEnd,
        y2 = buttonHeight,
        time = t * 60
    }
end

-- Helper functions

-- Center text within a specified horizontal area (x1 to x2)
local function drawTextCenteredInArea(y, text, x1, x2, bkg, txtcol)
    if bkg then mon.setBackgroundColor(bkg) end
    if txtcol then mon.setTextColor(txtcol) end
    local areaWidth = x2 - x1 + 1
    local startX = x1 + math.floor((areaWidth - #text)/2)
    mon.setCursorPos(startX, y)
    mon.write(text)
end

local function clearMonitor()
    mon.setBackgroundColor(backgroundColor)
    mon.setTextColor(textColor)
    mon.clear()
end

local function drawButtonsIdle()
    clearMonitor()
    for i, btn in ipairs(buttons) do
        mon.setBackgroundColor(buttonColor)
        -- Draw the button background
        for y = btn.y1, btn.y2 do
            mon.setCursorPos(btn.x1, y)
            mon.write(string.rep(" ", btn.x2 - btn.x1 + 1))
        end
        -- Draw the label centered in the button
        local label = tostring(timeOptions[i]).." Mins"
        local labelY = math.floor((btn.y1 + btn.y2)/2)
        drawTextCenteredInArea(labelY, label, btn.x1, btn.x2, buttonColor, textColor)
    end
end

local function within(x, y, btn)
    return x >= btn.x1 and x <= btn.x2 and y >= btn.y1 and y <= btn.y2
end

local function setRedstoneOutput(level)
    redstone.setAnalogOutput(redstoneSide, level)
end

local function startRun(totalSec)
    chosenTime = totalSec
    startTime = os.clock()
    state = "RUNNING"
    running = true
    setRedstoneOutput(15)   -- Full power from start (warmup + full)
    clearMonitor()
end

local function drawProgressBar()
    if not running then return end
    local now = os.clock()
    local elapsed = now - startTime

    local totalDisplayTime = chosenTime + cooldownTime
    if elapsed > totalDisplayTime then elapsed = totalDisplayTime end
    local fraction = elapsed / totalDisplayTime

    local w,h = mon.getSize()
    local barHeight = 3
    local barY = math.floor(h/2)

    -- Determine phase
    local barColor
    if elapsed <= warmupTime then
        barColor = warmupBarColor
    elseif elapsed <= chosenTime then
        barColor = fullBarColor
    else
        barColor = cooldownBarColor
    end

    -- Bar background
    mon.setBackgroundColor(barBackgroundColor)
    for y = barY, barY+barHeight-1 do
        mon.setCursorPos(1,y)
        mon.clearLine()
    end

    -- Fill portion
    local filledWidth = math.floor(w * fraction)
    if filledWidth > 0 then
        mon.setBackgroundColor(barColor)
        for y = barY, barY+barHeight-1 do
            mon.setCursorPos(1,y)
            mon.write(string.rep(" ", filledWidth))
        end
    end

    -- Time remaining
    local timeLeft = math.ceil(totalDisplayTime - elapsed)
    if timeLeft < 0 then timeLeft = 0 end
    local timeStr
    if timeLeft > 60 then
        timeStr = string.format("Time Remaining: %dm %ds", math.floor(timeLeft/60), timeLeft%60)
    else
        timeStr = "Time Remaining: "..timeLeft.."s"
    end

    mon.setBackgroundColor(backgroundColor)
    mon.setTextColor(textColor)
    -- Center these lines across the whole screen
    local title = "Sauna Therapy Progress"
    drawTextCenteredInArea(barY - 2, title, 1, w, backgroundColor, textColor)
    drawTextCenteredInArea(barY + barHeight + 1, timeStr, 1, w, backgroundColor, textColor)
end

local function updateRun()
    if not running then return end
    local now = os.clock()
    local elapsed = now - startTime

    -- Redstone control
    if elapsed > chosenTime then
        setRedstoneOutput(0)  -- After chosenTime ends
    else
        setRedstoneOutput(15) -- During warmup+full therapy
    end

    -- Check end condition
    if elapsed >= (chosenTime + cooldownTime) then
        running = false
        state = "IDLE"
        setRedstoneOutput(0)
        drawButtonsIdle()
        return
    end

    drawProgressBar()
end

local function handleTouch(x, y)
    if state == "IDLE" then
        -- Check button clicks
        for i, btn in ipairs(buttons) do
            if within(x, y, btn) then
                startRun(btn.time)
                return
            end
        end
    elseif state == "RUNNING" then
        local now = os.clock()
        local elapsed = now - startTime
        -- If in warmup/full therapy phase, clicking bar adds +1 minute
        if elapsed < chosenTime then
            local h = monH
            local barY = math.floor(h/2)
            local barHeight = 3
            if y >= barY and y < barY+barHeight then
                chosenTime = chosenTime + 60
            end
        end
    end
end

-- Setup
drawButtonsIdle()
local refreshTimer = os.startTimer(refreshInterval)

while true do
    local event, p1, p2, p3 = os.pullEvent()
    if event == "terminate" then
        setRedstoneOutput(0)
        break
    elseif event == "monitor_touch" then
        handleTouch(p2, p3)
    elseif event == "timer" and p1 == refreshTimer then
        updateRun()
        refreshTimer = os.startTimer(refreshInterval)
    end
end
