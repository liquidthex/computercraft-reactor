-- queueClient with auto-detection of modem side

-- Try opening all modems on all sides
local modemFound = false
for _, side in ipairs(rs.getSides()) do
  if peripheral.getType(side) == "modem" then
    rednet.open(side)
    modemFound = true
  end
end

-- If no modem was found, we can’t continue
if not modemFound then
  print("Error: No modem found on any side.")
  return
end

-- Optional: if you know your server’s computer ID, you can store it here
local serverID = nil  -- If nil, we'll broadcast to all. Or set a specific ID number here.

-- Main loop to collect user input and send it to the server
while true do
  write("Enter your search or URL (empty to quit): ")
  local input = read()
  
  if input == "" then
    print("Exiting client.")
    break
  end
  
  -- Compose the message for the server
  local message = "queue " .. input
  
  -- If you have a dedicated server ID, do:
  --   rednet.send(serverID, message)
  -- Otherwise, broadcast to all:
  rednet.broadcast(message)

  -- Optionally wait for confirmation from server (with 1-second timeout)
  local senderID, reply = rednet.receive(1)
  if senderID then
    print("Server says: " .. reply)
  else
    print("Request sent (no immediate reply).")
  end
end
