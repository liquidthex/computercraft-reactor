-- thexos/updateMonitor.lua
-- Script to monitor for update notifications and perform updates when necessary

-- Configuration
local githubUser = 'liquidthex'
local githubRepo = 'computercraft-thexos'
local githubBranch = 'main'        -- Change if using a different branch

-- Ensure HTTP API is enabled
if not http then
    error('HTTP API is not enabled in ComputerCraft. Enable it by setting "http_enable = true" in the mod config.')
end

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

-- Function to listen for chat messages
local function listenForChatMessages()
    while true do
        local event, username, message = os.pullEvent("chat")
        
        -- Debug: Print every chat message received
        print("Received chat message from " .. username .. ": " .. message)
        
        -- Check if the message contains the update trigger
        if message:find("%[ThexOS%]%s+Update Available") then
            print("Update notification received. Checking for updates...")
            performUpdate()
        end
    end
end


-- Start listening for chat messages
listenForChatMessages()
