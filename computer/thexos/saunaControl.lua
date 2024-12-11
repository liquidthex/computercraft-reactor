-- Configuration
local monitorSide = "back"   -- Your monitor peripheral name
local redstoneSide = "bottom"
local warmupTime = 60            -- seconds of warmup
local cooldownTime = 15          -- seconds of cooldown
local backgroundColor = colors.black
local buttonColor = colors.gray
local textColor = colors.white
local warmupBarColor = colors.orange
local fullBarColor = colors.lime
local cooldownBarColor = colors.red
local barBackgroundColor = colors.lightGray

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

local buttons = {}
local state = "IDLE"
local chosenTime = 0        -- total run time (in seconds) user selected (includes warmup)
local startTime = 0
local running = false

-- For timing the updates
local refreshInterval = 0.5  -- update the display every 0.5 seconds

-- Calculate button positions for the horizontal layout
-- 3 buttons side-by-side taking full width and height
local numButtons = #timeOptions
local buttonWidth = math.floor(monW / numButtons)
local buttonHeight = monH  -- Use full height
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

local function drawCenteredText(y, text, bkg, txtcol)
    mon.setBackgroundColor(bkg or backgroundColor)
    mon.setTextColor(txtcol or textColor)
    local w, h = mon.getSize()
    local x = math.floor((w - #text)/2) + 1
    mon.setCursorPos(x, y)
    mon.write(text)
end

local function clearMonitor()
    mon.setBackgroundColor(backgroundColor)
    mon.setTextColor(textColor)
    mon.clear()
end

local function drawButtonsIdle()
    clearMonitor()
    for i,btn in ipairs(buttons) do
        mon.setBackgroundColor(buttonColor)
        for y = btn.y1, btn.y2 do
            mon.setCursorPos(btn.x1, y)
            for x = btn.x1, btn.x2 do
                mon.write(" ")
            end
        end
        local label = tostring(timeOptions[i]).." Mins"
        local labelY = math.floor((btn.y1 + btn.y2)/2)
        drawCenteredText(labelY, label, buttonColor, textColor)
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
    setRedstoneOutput(15)   -- Full power during warmup and full therapy
    clearMonitor()
end

local function drawProgressBar()
    local now = os.clock()
    local elapsed = now - startTime
    if not running then return end

    local totalDisplayTime = chosenTime + cooldownTime
    local fraction = elapsed / totalDisplayTime
    if fraction > 1 then fraction = 1 end
    local w, h = mon.getSize()

    local barHeight = 3
    local barY = math.floor(h/2)

    -- Determine phase and color
    local barColor
    if elapsed <= warmupTime then
        barColor = warmupBarColor
    elseif elapsed <= chosenTime then
        barColor = fullBarColor
    else
        barColor = cooldownBarColor
    end

    -- Draw bar background
    mon.setBackgroundColor(barBackgroundColor)
    for y = barY, barY+barHeight-1 do
        mon.setCursorPos(1,y)
        mon.clearLine()
    end

    -- Fill portion of the bar
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
    drawCenteredText(barY - 2, "Sauna Therapy Progress", backgroundColor, textColor)
    drawCenteredText(barY + barHeight + 1, timeStr, backgroundColor, textColor)
end

local function updateRun()
    if not running then return end
    local now = os.clock()
    local elapsed = now - startTime

    -- During warmup + full therapy: redstone=15
    -- After chosenTime is reached: turn off redstone
    if elapsed > chosenTime then
        setRedstoneOutput(0)
    else
        setRedstoneOutput(15)
    end

    -- If we passed the total cycle (chosenTime + cooldownTime)
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
        -- Check which button was clicked
        for i, btn in ipairs(buttons) do
            if within(x, y, btn) then
                -- Start run: includes warmup (60s) + full therapy (chosenTime-60s)
                -- chosenTime is the total run (including warmup)
                startRun(btn.time)  
                return
            end
        end
    elseif state == "RUNNING" then
        local now = os.clock()
        local elapsed = now - startTime
        -- If in warmup or full therapy phase, clicking bar adds +1 minute
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
