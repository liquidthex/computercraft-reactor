-- thexos/boot.lua
-- Main boot script that handles updates and runs other programs

-- Configuration
local githubUser = 'liquidthex'
local githubRepo = 'computercraft-thexos'
local githubBranch = 'main'        -- Change if using a different branch

-- Ensure HTTP API is enabled
if not http then
    error('HTTP API is not enabled in ComputerCraft. Enable it by setting "http_enable = true" in the mod config.')
end

-- Check if multishell is available
if not multishell then
    error("Multishell is required to run this program. Please use a version of ComputerCraft that supports multishell.")
end

-- Set the computer label to "thexos"
os.setComputerLabel("thexos")

-- Function to load stored commit hash
local function loadStoredCommitHash()
    if fs.exists(".thexos_commit_hash") then
        local file = fs.open(".thexos_commit_hash", "r")
        local hash = file.readAll()
        file.close()
        return hash
    else
        return nil
    end
end

-- Function to save commit hash
local function saveCommitHash(hash)
    local file = fs.open(".thexos_commit_hash", "w")
    file.write(hash)
    file.close()
end

-- Function to perform the update
local function performUpdate()
    print('Update available. Downloading update.lua and running update.')

    -- Get the latest commit hash from GitHub API
    local latestHash = getLatestCommitHash()

    -- Download update.lua from the latest commit
    local updateURL = 'https://raw.githubusercontent.com/' .. githubUser .. '/' .. githubRepo .. '/' .. latestHash .. '/update.lua'
    local response = http.get(updateURL)
    if not response then
        error('Failed to download update.lua.')
    end

    -- Save update.lua in the root directory
    local file = fs.open('update.lua', 'w')
    file.write(response.readAll())
    file.close()
    response.close()

    -- Run update.lua
    shell.run('update.lua')

    -- Delete update.lua after execution
    if fs.exists('update.lua') then
        fs.delete('update.lua')
    end

    -- Save the new commit hash
    saveCommitHash(latestHash)

    -- Reboot the computer to apply updates
    print('Update complete. Rebooting...')
    os.reboot()
end

-- Function to get the latest commit hash from GitHub API
function getLatestCommitHash()
    local apiURL = 'https://api.github.com/repos/' .. githubUser .. '/' .. githubRepo .. '/commits/' .. githubBranch
    local response = http.get(apiURL)
    if not response then
        error('Failed to retrieve the latest commit hash.')
    end
    local jsonResponse = response.readAll()
    response.close()

    -- Extract the commit SHA using pattern matching
    local commitSHA = jsonResponse:match('"sha"%s*:%s*"(.-)"')
    if not commitSHA then
        error('Failed to parse the latest commit hash.')
    end
    return commitSHA
end

-- Function to run a script when specified peripherals are connected
local function runOnFindPeripherals(peripheralsList, scriptPath)
    for _, peripheralName in ipairs(peripheralsList) do
        if not peripheral.find(peripheralName) then
            print("Peripheral not found: " .. peripheralName .. ". Skipping " .. scriptPath)
            return
        end
    end

    if fs.exists(scriptPath) then
        -- Launch the script in a new multishell tab
        multishell.launch({}, scriptPath)
        print("Launched " .. scriptPath .. " in background.")
    else
        print("Script not found: " .. scriptPath)
    end
end

-- Main program logic
local function main()
    -- Check for updates on startup
    local latestHash = getLatestCommitHash()
    local storedHash = loadStoredCommitHash()

    if not storedHash or latestHash ~= storedHash then
        performUpdate()
    else
        print('No update needed.')
    end

    -- Launch scripts based on connected peripherals
    runOnFindPeripherals({"monitor", "fissionReactorLogicAdapter"}, "thexos/reactorControl.lua")

    -- Clear the screen and reset the cursor position before printing motd
    term.clear()
    term.setCursorPos(1, 1)

    -- Print the contents of thexos/motd.txt upon successful startup
    if fs.exists("thexos/motd.txt") then
        local file = fs.open("thexos/motd.txt", "r")
        local motd = file.readAll()
        file.close()
        print(motd)
    else
        print("motd.txt not found.")
    end

    -- Main function ends here, console remains free for user input
end

-- Run the main function
main()
