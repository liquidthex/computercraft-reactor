-- queueServer
-- Attempt to open a modem for Rednet communication automatically
local modemFound = false
for _, side in ipairs(rs.getSides()) do
  if peripheral.getType(side) == "modem" then
    rednet.open(side)
    modemFound = true
  end
end

if not modemFound then
  print("Error: No modem found on any side.")
  return
end

-- Table to hold all queued items
local queue = {}

-- This function continuously checks if there's anything to play.
-- If yes, remove the first item in the queue and play it until it finishes.
local function handleQueue()
  while true do
    if #queue > 0 then
      -- Dequeue first entry
      local video = table.remove(queue, 1)

      print("Now playing: " .. video)
      -- This will block until 'youcube' command finishes
      shell.run("monitor", "top", "youcube", video)

      print("Finished playing: " .. video)
    else
      -- No videos to play, just wait a bit before checking again
      sleep(1)
    end
  end
end

-- This function will listen for messages over rednet and enqueue them
local function listenForRequests()
  print("Server listening for queue requests...")
  while true do
    local senderID, message = rednet.receive()

    -- We can parse a command from the message if you like,
    -- or assume the entire message is just the query.
    -- Example: "queue rick astley" => command="queue", arg="rick astley"
    local command, arg = message:match("^(%S+)%s+(.*)$")

    if command == "queue" and arg ~= "" then
      table.insert(queue, arg)
      print("Enqueued request from Computer #" .. senderID .. ": " .. arg)
      -- Optionally send a confirmation
      rednet.send(senderID, "Queued: " .. arg)
    else
      -- If you want to handle unknown messages:
      rednet.send(senderID, "Unknown request: " .. message)
    end
  end
end

-- Run both tasks (listen and handle queue) in parallel
parallel.waitForAny(handleQueue, listenForRequests)
