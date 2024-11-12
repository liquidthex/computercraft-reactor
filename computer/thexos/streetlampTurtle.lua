-- streetlampTurtle.lua

-- Open rednet on the side where the modem is connected (adjust "left" as needed)
rednet.open("left")

-- Configurable lamp post design (from top to bottom)
local lampPostDesign = {
    "minecraft:glowstone",
    "minecraft:oak_fence",
    "minecraft:oak_fence",
    "minecraft:oak_fence"
}

-- Function to restock necessary items
local function restockItems()
    -- Empty extra items
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount() > 0 then
            turtle.dropDown()
        end
    end

    -- Calculate required items
    local requiredItems = {}
    for _, item in ipairs(lampPostDesign) do
        requiredItems[item] = (requiredItems[item] or 0) + 1
    end

    -- Fetch items from the chest below
    for itemName, itemCount in pairs(requiredItems) do
        local collected = 0
        for slot = 1, 16 do
            turtle.select(slot)
            if collected >= itemCount then
                break
            end
            if turtle.suckDown() then
                local detail = turtle.getItemDetail()
                if detail and detail.name == itemName then
                    collected = collected + detail.count
                else
                    -- Return unwanted items
                    turtle.dropDown()
                end
            else
                print("Not enough items: " .. itemName)
                return false
            end
        end
    end

    return true
end

-- Function to empty the turtle's inventory
local function emptyInventory()
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount() > 0 then
            turtle.dropDown()
        end
    end
end

-- Function to select a specific block in the inventory
local function selectBlock(blockName)
    for slot = 1, 16 do
        local detail = turtle.getItemDetail(slot)
        if detail and detail.name == blockName then
            turtle.select(slot)
            return true
        end
    end
    return false
end

-- Routine to execute during the night
local function nightRoutine()
    print("Starting night routine...")
    -- Step 1: Restock items
    if not restockItems() then
        print("Failed to restock items.")
        return
    end

    -- Step 2: Break the block above
    turtle.digUp()

    -- Step 3: Move up (number of blocks in lampPostDesign + 1)
    -- The +1 accounts for moving above ground level
    for i = 1, #lampPostDesign + 1 do
        if not turtle.up() then
            turtle.digUp()
            turtle.up()
        end
    end

    -- Step 4: Place the blocks from the lampPostDesign
    for i = 1, #lampPostDesign do
        local block = lampPostDesign[i]
        if selectBlock(block) then
            turtle.placeDown()
        else
            print("Missing block: " .. block)
        end
        if i < #lampPostDesign then
            turtle.down()
        end
    end

    -- Step 5: Move down to just below the surface
    for i = 1, #lampPostDesign do
        turtle.down()
    end

    -- Step 6: Replace the ground block
    if selectBlock("minecraft:dirt") or selectBlock("minecraft:grass_block") then
        turtle.placeUp()
    else
        print("No dirt or grass block to replace.")
    end
    print("Night routine completed.")
end

-- Routine to execute during the day
local function dayRoutine()
    print("Starting day routine...")
    -- Step 1: Empty inventory
    emptyInventory()

    -- Step 2: Break the block above
    turtle.digUp()

    -- Step 3: Move up (number of blocks in lampPostDesign + 1) and break blocks
    for i = 1, #lampPostDesign + 1 do
        if not turtle.up() then
            turtle.digUp()
            turtle.up()
        end
    end

    -- Step 4: Break the blocks from the lampPostDesign
    for i = 1, #lampPostDesign do
        turtle.digDown()
        if i < #lampPostDesign then
            turtle.down()
        end
    end

    -- Step 5: Move down to the idle position
    for i = 1, #lampPostDesign do
        turtle.down()
    end

    -- Step 6: Replace the ground block
    if selectBlock("minecraft:dirt") or selectBlock("minecraft:grass_block") then
        turtle.placeUp()
    else
        print("No dirt or grass block to replace.")
    end

    -- Step 7: Empty inventory again
    emptyInventory()
    print("Day routine completed.")
end

-- Main event loop
print("Waiting for day/night signals...")
while true do
    local event, senderId, message, protocol = os.pullEvent("rednet_message")
    if protocol == "thexos" then
        if message == "night" then
            nightRoutine()
        elseif message == "day" then
            dayRoutine()
        else
            print("Unknown message: " .. message)
        end
    end
end
