import asyncio
import websockets
import subprocess
import threading
import json

# Dictionary to keep track of client tasks
client_tasks = {}

async def handle_client(websocket, path):
    # Receive the initial message from the client specifying the stream URL
    try:
        message = await websocket.recv()
        request = json.loads(message)
        stream_url = request.get('stream_url')

        if not stream_url:
            await websocket.send(json.dumps({'error': 'No stream URL provided.'}))
            await websocket.close()
            return

        print(f"Client connected. Streaming: {stream_url}")

        # Start streaming the audio to the client
        await stream_audio(websocket, stream_url)
    except websockets.exceptions.ConnectionClosed:
        print("Connection closed.")
    except Exception as e:
        print(f"Error: {e}")

async def stream_audio(websocket, stream_url):
    # FFmpeg command to stream and convert audio to DFPWM
    ffmpeg_cmd = [
        'ffmpeg',
        '-i', stream_url,
        '-f', 'dfpwm',      # Output format DFPWM1
        '-ar', '48000',      # Sample rate
        '-ac', '1',          # Mono audio
        '-vn',               # No video
        'pipe:1'             # Output to stdout
    ]

    # Start the FFmpeg process
    ffmpeg_proc = subprocess.Popen(ffmpeg_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

    try:
        while True:
            # Read DFPWM data from FFmpeg
            dfpwm_data = ffmpeg_proc.stdout.read(4096)
            if not dfpwm_data:
                break

            # Send the DFPWM data over the WebSocket
            await websocket.send(dfpwm_data)
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected.")
    finally:
        ffmpeg_proc.kill()

def start_server():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    server = websockets.serve(handle_client, '0.0.0.0', 8765)

    loop.run_until_complete(server)
    loop.run_forever()

if __name__ == "__main__":
    print("Starting the streaming server...")
    server_thread = threading.Thread(target=start_server)
    server_thread.start()
