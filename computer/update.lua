-- update.lua
-- Update script for ComputerCraft with cache busting and commit hash display

-- Configuration
local githubUser = 'liquidthex'
local githubRepo = 'computercraft-reactor'
local githubBranch = 'main' -- Change if using a different branch
local folderPath = 'computer'

local baseURL = 'https://raw.githubusercontent.com/' .. githubUser .. '/' .. githubRepo .. '/' .. githubBranch .. '/' .. folderPath .. '/'

-- Seed the random number generator
math.randomseed(os.time())

-- Function to download a file with cache busting
local function downloadFile(filePath)
    -- Generate a cache-busting query parameter
    local cacheBuster = '?cb=' .. math.random(1, 1000000)
    local url = baseURL .. filePath .. cacheBuster

    local response = http.get(url)
    if response then
        -- Create any necessary subdirectories
        local dir = fs.getDir(filePath)
        if dir and dir ~= '' then
            fs.makeDir(dir)
        end

        local file = fs.open(filePath, 'w')
        file.write(response.readAll())
        file.close()
        response.close()
        print('Downloaded ' .. filePath)
    else
        print('Failed to download ' .. filePath)
    end
end

-- Function to get the latest commit hash from GitHub API
local function getLatestCommitHash()
    local apiURL = 'https://api.github.com/repos/' .. githubUser .. '/' .. githubRepo .. '/commits/' .. githubBranch
    local response = http.get(apiURL)

    if response then
        local jsonResponse = response.readAll()
        response.close()

        -- Extract the commit SHA using pattern matching
        local commitSHA = jsonResponse:match('"sha"%s*:%s*"(%w+)"')
        return commitSHA
    else
        print('Failed to retrieve the latest commit hash.')
        return nil
    end
end

-- Ensure HTTP API is enabled
if not http then
    print('HTTP API is not enabled in ComputerCraft.')
    print('Enable it by setting "http_enable = true" in the mod config.')
    return
end

-- Get the latest commit hash
local commitHash = getLatestCommitHash()

-- Download files.txt to get the list of files
local cacheBuster = '?cb=' .. math.random(1, 1000000)
local filesTxtUrl = baseURL .. 'files.txt' .. cacheBuster
local response = http.get(filesTxtUrl)
local files = {}

if response then
    local content = response.readAll()
    response.close()
    for line in content:gmatch('[^\r\n]+') do
        -- Ignore empty lines and comments
        if line:match('^%s*$') or line:match('^%s*%-%-') then
            -- Skip this line
        else
            table.insert(files, line)
        end
    end
    print('Retrieved file list from files.txt.')
else
    print('Failed to download files.txt.')
    return
end

-- Download each file except startup.lua
for _, filePath in ipairs(files) do
    if filePath ~= "startup.lua" then
        downloadFile(filePath)
    end
end

-- Download startup.lua last
if fs.exists("startup.lua") then
    fs.delete("startup.lua")
end
downloadFile("startup.lua")

-- Display the commit hash in the final message
if commitHash then
    print('Updated to commit: ' .. commitHash)
else
    print('Update complete.')
end
