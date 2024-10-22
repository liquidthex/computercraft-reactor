-- monitor.lua
-- Script to display reactor status on an adjacent monitor

-- Configuration
local monitorSide = "right"       -- The side where the monitor is connected
local reactorName = "fissionReactorLogicAdapter_0"   -- The name or side of the reactor peripheral
local updateInterval = 5          -- Time in seconds between updates

-- Wrap the monitor peripheral
local monitor = peripheral.wrap(monitorSide)

-- Find the reactor peripheral
local reactor = peripheral.wrap(reactorName)

-- Check if the peripherals are connected
if not monitor then
    print("No monitor found on side: " .. monitorSide)
    return
end

if not reactor then
    print("No reactor found with name: " .. reactorName)
    return
end

-- Monitor setup
monitor.setTextScale(0.5)  -- Adjust text scale as needed
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

-- Function to format numbers with commas
local function formatNumber(num)
    local formatted = tostring(math.floor(num))
    while true do
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- Function to convert Kelvin to Celsius
local function kelvinToCelsius(kelvin)
    return kelvin - 273.15
end

-- Main loop to update the monitor
while true do
    -- Get reactor status
    local status = reactor.getStatus() and "Active" or "Inactive"
    local temperatureK = reactor.getTemperature()
    local temperatureC = kelvinToCelsius(temperatureK)
    local damagePercent = reactor.getDamagePercent()
    local coolant = reactor.getCoolant()
    local coolantPercent = reactor.getCoolantFilledPercentage() * 100
    local heatedCoolant = reactor.getHeatedCoolant()
    local heatedCoolantPercent = reactor.getHeatedCoolantFilledPercentage() * 100
    local fuel = reactor.getFuel()
    local fuelPercent = reactor.getFuelFilledPercentage() * 100
    local fuelNeeded = reactor.getFuelNeeded()
    local fuelCapacity = reactor.getFuelCapacity()
    local waste = reactor.getWaste()
    local wastePercent = reactor.getWasteFilledPercentage() * 100
    local burnRate = reactor.getBurnRate()
    local actualBurnRate = reactor.getActualBurnRate()
    local maxBurnRate = reactor.getMaxBurnRate()
    local heatingRate = reactor.getHeatingRate()
    local environmentalLoss = reactor.getEnvironmentalLoss()
    local forceDisabled = reactor.isForceDisabled() and "Yes" or "No"

    -- Clear the monitor
    monitor.clear()
    monitor.setCursorPos(1,1)

    -- Display reactor information
    monitor.setTextColor(colors.yellow)
    monitor.write("Mekanism Fission Reactor")
    monitor.setCursorPos(1,2)
    monitor.setTextColor(colors.white)

    monitor.write("Status: " .. status)
    monitor.setCursorPos(1,3)
    monitor.write(string.format("Temperature: %.2f C", temperatureC))
    monitor.setCursorPos(1,4)
    monitor.write(string.format("Damage: %.2f%%", damagePercent * 100))
    monitor.setCursorPos(1,5)
    monitor.write("")

    monitor.write("Coolant:")
    monitor.setCursorPos(1,6)
    monitor.write(" - Type: " .. (coolant.name or "None"))
    monitor.setCursorPos(1,7)
    monitor.write(" - Amount: " .. formatNumber(coolant.amount or 0))
    monitor.setCursorPos(1,8)
    monitor.write(string.format(" - Filled: %.2f%%", coolantPercent))
    monitor.setCursorPos(1,9)
    monitor.write("")

    monitor.write("Heated Coolant:")
    monitor.setCursorPos(1,10)
    monitor.write(" - Type: " .. (heatedCoolant.name or "None"))
    monitor.setCursorPos(1,11)
    monitor.write(" - Amount: " .. formatNumber(heatedCoolant.amount or 0))
    monitor.setCursorPos(1,12)
    monitor.write(string.format(" - Filled: %.2f%%", heatedCoolantPercent))
    monitor.setCursorPos(1,13)
    monitor.write("")

    monitor.write("Fuel:")
    monitor.setCursorPos(1,14)
    monitor.write(" - Type: " .. (fuel.name or "None"))
    monitor.setCursorPos(1,15)
    monitor.write(" - Amount: " .. formatNumber(fuel.amount or 0))
    monitor.setCursorPos(1,16)
    monitor.write(string.format(" - Filled: %.2f%%", fuelPercent))
    monitor.setCursorPos(1,17)
    monitor.write("")

    monitor.write("Waste:")
    monitor.setCursorPos(1,18)
    monitor.write(" - Type: " .. (waste.name or "None"))
    monitor.setCursorPos(1,19)
    monitor.write(" - Amount: " .. formatNumber(waste.amount or 0))
    monitor.setCursorPos(1,20)
    monitor.write(string.format(" - Filled: %.2f%%", wastePercent))
    monitor.setCursorPos(1,21)
    monitor.write("")

    monitor.write(string.format("Burn Rate: %.2f mB/t", burnRate))
    monitor.setCursorPos(1,22)
    monitor.write(string.format("Actual Burn Rate: %.2f mB/t", actualBurnRate))
    monitor.setCursorPos(1,23)
    monitor.write(string.format("Max Burn Rate: %.2f mB/t", maxBurnRate))
    monitor.setCursorPos(1,24)
    monitor.write(string.format("Heating Rate: %s mB/t", formatNumber(heatingRate)))
    monitor.setCursorPos(1,25)
    monitor.write(string.format("Environmental Loss: %.2f", environmentalLoss))
    monitor.setCursorPos(1,26)
    monitor.write("Force Disabled: " .. forceDisabled)

    -- Wait before updating again
    sleep(updateInterval)
end
