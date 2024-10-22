-- update.lua
-- Update script for ComputerCraft

-- Configuration
local githubUser = 'liquidthex'
local githubRepo = 'computercraft-reactor'
local githubBranch = 'main' -- Change if using a different branch
local folderPath = 'computer'

local baseURL = 'https://raw.githubusercontent.com/' .. githubUser .. '/' .. githubRepo .. '/' .. githubBranch .. '/' .. folderPath .. '/'

-- Function to download a file
local function downloadFile(filePath)
    local url = baseURL .. filePath
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

-- Ensure HTTP API is enabled
if not http then
    print('HTTP API is not enabled in ComputerCraft.')
    print('Enable it by setting "http_enable = true" in the mod config.')
    return
end

-- Download files.txt to get the list of files
local filesTxtUrl = baseURL .. 'files.txt'
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

print('Update complete.')
