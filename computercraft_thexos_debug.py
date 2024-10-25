import asyncio
import websockets

async def server(websocket, path):
    print("Connection established.")
    try:
        while True:
            # Accept command input from the console
            command = input("Enter command: ")
            if command:
                await websocket.send(command)
                response = await websocket.recv()
                print("Response:", response)
            else:
                print("Empty command, connection closing...")
                break
    except websockets.exceptions.ConnectionClosed:
        print("Connection closed.")

start_server = websockets.serve(server, "127.0.0.1", 8000)

asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
