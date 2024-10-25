-- thexosDebug.lua
local function thexosDebug(func)
    -- Redirect output to both terminal and a file
    local oldOutput = term.current()
    local file = fs.open("thexosDebugOutput.txt", "a")  -- Append mode

    local newOutput = {
        write = function(self, ...)
            local args = {...}
            local output = table.concat(args)
            oldOutput.write(output)
            file.write(output)
        end,
        getCursorPos = function()
            return oldOutput.getCursorPos()
        end,
        setCursorPos = function(_, x, y)
            oldOutput.setCursorPos(x, y)
        end,
        clear = oldOutput.clear,
        clearLine = oldOutput.clearLine,
        scroll = oldOutput.scroll,
        getSize = oldOutput.getSize
    }

    -- Check if the terminal supports colors and add color methods conditionally
    if oldOutput.isColor and oldOutput.isColor() then
        newOutput.isColor = oldOutput.isColor
        newOutput.setTextColor = oldOutput.setTextColor
        newOutput.setTextColour = oldOutput.setTextColour
        newOutput.setBackgroundColor = oldOutput.setBackgroundColor
        newOutput.setBackgroundColour = oldOutput.setBackgroundColour
    end

    -- Set new terminal output
    term.redirect(newOutput)

    -- Execute the function and capture the result
    local status, result = pcall(func)
    if not status then
        print("Error: ", result)
    else
        print("Result: ", result)
    end

    -- Restore old terminal output and close file
    term.redirect(oldOutput)
    file.close()
end

return thexosDebug
