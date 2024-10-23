-- update.lua
-- Script to recursively update files from GitHub using the latest commit hash

-- Configuration
local githubUser = 'liquidthex'
local githubRepo = 'computercraft-thexos'
local githubBranch = 'main' -- Change if using a different branch

-- Ensure HTTP API is enabled
if not http then
    error('HTTP API is not enabled in ComputerCraft. Enable it by setting "http_enable = true" in the mod config.')
end

-- Function to get the latest commit hash from GitHub API
local function getLatestCommitHash()
    local apiURL = 'https://api.github.com/repos/' .. githubUser .. '/' .. githubRepo .. '/commits/' .. githubBranch
    local headers = {
        ["Cache-Control"] = "no-cache"
    }
    local response = http.get(apiURL, headers)
    if not response then
        error('Failed to retrieve the latest commit hash.')
    end
    local jsonResponse = response.readAll()
    response.close()

    -- Parse the JSON response
    local data = textutils.unserializeJSON(jsonResponse)
    if not data or not data.sha then
        error('Failed to parse the latest commit hash.')
    end
    return data.sha
end

-- Function to get the tree of files in the repository
local function getRepoTree(commitHash)
    local apiURL = 'https://api.github.com/repos/' .. githubUser .. '/' .. githubRepo .. '/git/trees/' .. commitHash .. '?recursive=1'
    local headers = {
        ["Cache-Control"] = "no-cache"
    }
    local response = http.get(apiURL, headers)
    if not response then
        error('Failed to retrieve the repository tree.')
    end
    local jsonResponse = response.readAll()
    response.close()

    -- Parse the JSON response
    local data = textutils.unserializeJSON(jsonResponse)
    if not data or not data.tree then
        error('Failed to parse the repository tree.')
    end
    return data.tree
end

-- Function to recursively download files from the repository
local function downloadFilesFromTree(tree, commitHash)
    for _, item in ipairs(tree) do
        if item.type == "blob" and item.path:find("^computer/") then
            -- Construct the local path by removing the "computer/" prefix
            local localPath = item.path:gsub("^computer/", "")
            -- Construct the download URL using the commit hash
            local downloadURL = 'https://raw.githubusercontent.com/' .. githubUser .. '/' .. githubRepo .. '/' .. commitHash .. '/' .. item.path

            -- Download the file
            print('Downloading ' .. downloadURL .. ' to ' .. localPath)
            local headers = {
                ["Cache-Control"] = "no-cache"
            }
            local response = http.get(downloadURL, headers)
            if not response then
                error('Failed to download ' .. item.path)
            end
            local content = response.readAll()
            response.close()

            -- Ensure the directory exists
            local dir = fs.getDir(localPath)
            if dir ~= "" and not fs.exists(dir) then
                fs.makeDir(dir)
            end

            -- Save the content to the specified path
            local file = fs.open(localPath, 'w')
            file.write(content)
            file.close()
        end
    end
end

-- Save the latest commit hash
local function saveCommitHash(hash)
    local file = fs.open(".thexos_commit_hash", "w")
    file.write(hash)
    file.close()
end

-- Main update function
local function performUpdate()
    -- Get the latest commit hash
    local latestHash = getLatestCommitHash()

    -- Get the repository tree
    local repoTree = getRepoTree(latestHash)

    -- Download files from the tree
    downloadFilesFromTree(repoTree, latestHash)

    -- Save the new commit hash
    saveCommitHash(latestHash)

    print('Update complete.')
end

-- Perform the update
performUpdate()
