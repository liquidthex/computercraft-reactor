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

-- Function to get the latest commit hash from GitHub API
local function getLatestCommitHash()
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

-- Load stored commit hash
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

-- Save commit hash
local function saveCommitHash(hash)
    local file = fs.open(".thexos_commit_hash", "w")
    file.write(hash)
    file.close()
end

-- Main logic
local latestHash = getLatestCommitHash()
local storedHash = loadStoredCommitHash()

if latestHash ~= storedHash then
    -- An update is needed
    print('Update available. Downloading update.lua and running update.')

    -- Download update.lua to the root directory
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
else
    print('No update needed.')
end

-- After update (or if no update needed), proceed to detect peripherals and run reactorControl.lua if applicable

-- Detect connected peripherals
local monitor = peripheral.find("monitor")
local reactor = peripheral.find("fissionReactorLogicAdapter")

-- If both peripherals are present, run reactorControl.lua in the background
if monitor and reactor then
    if fs.exists("thexos/reactorControl.lua") then
        if multishell then
            -- Launch reactorControl.lua in a new tab
            multishell.launch({}, "thexos/reactorControl.lua")
            print("Launched reactorControl.lua in background.")
        else
            -- Run reactorControl.lua normally
            shell.run("thexos/reactorControl.lua")
        end
    else
        print("reactorControl.lua not found.")
    end
else
    print("Monitor or reactor not detected. Skipping reactorControl.lua.")
end

-- Print the contents of thexos/motd.txt upon successful startup
if fs.exists("thexos/motd.txt") then
    local file = fs.open("thexos/motd.txt", "r")
    local motd = file.readAll()
    file.close()
    print(motd)
else
    print("motd.txt not found.")
end
