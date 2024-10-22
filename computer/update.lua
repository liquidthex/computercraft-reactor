-- update.lua
-- Update script for ComputerCraft

-- Configuration
local githubUser = 'liquidthex'
local githubRepo = 'computercraft-reactor'
local githubBranch = 'main' -- Change if using a different branch
local folderPath = 'computer'

local baseURL = 'https://raw.githubusercontent.com/' .. githubUser .. '/' .. githubRepo .. '/' .. githubBranch .. '/' .. folderPath .. '/'

-- Function to download a file
local function downloadFile(filename)
    local url = baseURL .. filename
    local response = http.get(url)
    if response then
        local file = fs.open(filename, 'w')
        file.write(response.readAll())
        file.close()
        response.close()
        print('Downloaded ' .. filename)
    else
        print('Failed to download ' .. filename)
    end
end

-- Ensure HTTP API is enabled
if not http then
    print('HTTP API is not enabled in ComputerCraft.')
    print('Enable it by setting "enableAPI_http = true" in the mod config.')
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
        table.insert(files, line)
    end
    print('Retrieved file list from files.txt.')
else
    print('Failed to download files.txt.')
    return
end

-- Download each file
for _, filename in ipairs(files) do
    downloadFile(filename)
end

print('Update complete.')
