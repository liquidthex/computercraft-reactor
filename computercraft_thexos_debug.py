# computercraft_thexos_debug.py
import sys
import asyncio
import websockets

async def command_prompt(uri):
    async with websockets.connect(uri) as websocket:
        print("Connected to ComputerCraft debug server.")
        print("Type 'exit' to quit.")

        while True:
            command = input(">>> ")
            if command.lower() == 'exit':
                print("Exiting...")
                break
            
            # Send the command over WebSocket
            await websocket.send(command)
            
            # Wait for and print the response
            response = await websocket.recv()
            print(response)

async def main():
    if len(sys.argv) < 2:
        print("Usage: python computercraft_thexos_debug.py ws://<Minecraft_Computer_IP>:<port>")
        sys.exit(1)
    
    uri = sys.argv[1]
    await command_prompt(uri)

if __name__ == "__main__":
    asyncio.run(main())
