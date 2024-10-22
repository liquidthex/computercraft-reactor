-- bootstrap.lua
-- Script to bootstrap the ThexOS installation by downloading and running update.lua

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

-- Main logic
local latestHash = getLatestCommitHash()

-- Download update.lua
print('Downloading update.lua...')
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
print('Running update.lua...')
shell.run('update.lua')

-- Delete update.lua after execution
if fs.exists('update.lua') then
    fs.delete('update.lua')
end

print('Bootstrap complete. Rebooting...')
os.reboot()
