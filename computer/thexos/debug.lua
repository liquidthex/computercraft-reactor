-- debug.lua
local function thexosDebug(func)
    -- Redirect output to both terminal and a file
    local oldOutput = term.current()
    local file = fs.open("thexosDebugOutput.txt", "a")  -- Append mode

    local newOutput = {
        write = function(self, ...)
            oldOutput.write(...)
            file.write(...)
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
        isColor = oldOutput.isColor,
        getSize = oldOutput.getSize,
        setTextColor = oldOutput.setTextColor,
        setTextColour = oldOutput.setTextColour,
        setBackgroundColor = oldOutput.setBackgroundColor,
        setBackgroundColour = oldOutput.setBackgroundColour,
    }

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
