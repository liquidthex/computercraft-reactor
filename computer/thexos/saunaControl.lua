-- Configuration
local monitorSide = "monitor"    -- Adjust to your monitor's peripheral name
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
local chosenTime = 0        -- user chosen total run time in seconds (excludes cooldown)
local startTime = 0
local running = false

local endOfRunTime = 0      -- when chosenTime ends (after warmup+full)
local cooldownStartTime = 0

-- Helper functions
local function drawCenteredText(y, text, bkg, txtcol, scale)
    scale = scale or 1
    mon.setTextScale(scale)
    local w, h = mon.getSize()
    local x = math.floor((w - #text)/2) + 1
    mon.setCursorPos(x, y)
    if bkg then mon.setBackgroundColor(bkg) end
    if txtcol then mon.setTextColor(txtcol) end
    mon.write(text)
    mon.setTextScale(1)
end

local function clearMonitor()
    mon.setBackgroundColor(backgroundColor)
    mon.setTextColor(textColor)
    mon.clear()
end

local function drawButtonsIdle()
    clearMonitor()
    local numButtons = #timeOptions
    local buttonHeight = math.floor(monH / numButtons)
    for i, t in ipairs(timeOptions) do
        local yStart = (i-1)*buttonHeight + 1
        local yEnd = i*buttonHeight
        mon.setBackgroundColor(buttonColor)
        for y = yStart, yEnd do
            mon.setCursorPos(1,y)
            mon.clearLine()
        end
        local label = tostring(t).." Mins"
        drawCenteredText(math.floor((yStart+yEnd)/2), label, buttonColor, textColor)
        buttons[i] = {x1=1, y1=yStart, x2=monW, y2=yEnd, time=t*60} -- in seconds
    end
end

local function within(x,y, btn)
    return x >= btn.x1 and x <= btn.x2 and y >= btn.y1 and y <= btn.y2
end

local function setRedstoneOutput(level)
    redstone.setAnalogOutput(redstoneSide, level)
end

local function startRun(totalSec)
    chosenTime = totalSec
    startTime = os.clock()
    endOfRunTime = startTime + chosenTime
    cooldownStartTime = endOfRunTime -- cooldown starts immediately after run ends
    state = "RUNNING"
    running = true
    setRedstoneOutput(15)   -- Turn on at full from the start
    clearMonitor()
end

local function drawProgressBar(elapsed)
    -- elapsed: how long since the run started
    -- phases:
    -- 0 to warmupTime: warmup (bar color: warmupBarColor)
    -- warmupTime to chosenTime: full therapy (fullBarColor)
    -- chosenTime to chosenTime+cooldownTime: cooldown (cooldownBarColor, redstone=0)

    local totalDisplayTime = chosenTime + cooldownTime
    local fraction = math.min(elapsed / totalDisplayTime, 1)

    local barColor
    if elapsed <= warmupTime then
        -- warmup phase
        barColor = warmupBarColor
    elseif elapsed <= chosenTime then
        -- full therapy phase
        barColor = fullBarColor
    else
        -- cooldown phase
        barColor = cooldownBarColor
    end

    local w,h = mon.getSize()
    local barHeight = 3
    local barY = math.floor(h/2)

    -- Draw bar background
    mon.setBackgroundColor(barBackgroundColor)
    for y = barY, barY+barHeight-1 do
        mon.setCursorPos(1,y)
        mon.clearLine()
    end

    -- Fill portion of the bar
    local filledWidth = math.floor(w * fraction)
    mon.setBackgroundColor(barColor)
    for y = barY, barY+barHeight-1 do
        mon.setCursorPos(1,y)
        for x = 1, filledWidth do
            mon.write(" ")
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

    drawCenteredText(barY - 2, "Sauna Therapy Progress", backgroundColor, textColor)
    drawCenteredText(barY + barHeight + 1, timeStr, backgroundColor, textColor)
end

local function updateRun()
    if not running then return end
    local now = os.clock()
    local elapsed = now - startTime

    if elapsed <= chosenTime then
        -- During warmup + full therapy: redstone = 15
        setRedstoneOutput(15)
    else
        -- After chosenTime ends: turn off redstone
        setRedstoneOutput(0)
    end

    -- If we passed the cooldown end
    if elapsed >= chosenTime + cooldownTime then
        -- End the run
        running = false
        state = "IDLE"
        setRedstoneOutput(0)
        drawButtonsIdle()
        return
    end

    -- Redraw progress bar
    drawProgressBar(elapsed)
end

local function handleTouch(x, y)
    if state == "IDLE" then
        -- Check if clicked a button
        for i, btn in ipairs(buttons) do
            if within(x, y, btn) then
                startRun(btn.time)
                break
            end
        end
    elseif state == "RUNNING" then
        -- If user clicks on the progress bar area, add 1 minute if we're still in warmup or full phase
        local now = os.clock()
        local elapsed = now - startTime
        if elapsed <= chosenTime then
            local w,h = mon.getSize()
            local barY = math.floor(h/2)
            local barHeight = 3
            if y >= barY and y < barY+barHeight then
                -- Add 60 seconds to chosenTime
                chosenTime = chosenTime + 60
                endOfRunTime = startTime + chosenTime
            end
        end
    end
end

-- Main
drawButtonsIdle()

while true do
    updateRun()
    local event, p1, p2, p3 = os.pullEventRaw()
    if event == "terminate" then
        setRedstoneOutput(0)
        error("Terminated")
    elseif event == "monitor_touch" then
        handleTouch(p2, p3)
    end
end
