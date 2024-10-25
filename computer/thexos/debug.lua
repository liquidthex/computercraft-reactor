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
        getCursorPos = oldOutput.getCursorPos,
        setCursorPos = oldOutput.setCursorPos,
        clear = oldOutput.clear,
        clearLine = oldOutput.clearLine,
        scroll = oldOutput.scroll,
        getSize = oldOutput.getSize,
    }

    -- Ensure color methods are only added if they exist in the old output
    if type(oldOutput.isColor) == "function" and oldOutput.isColor() then
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
