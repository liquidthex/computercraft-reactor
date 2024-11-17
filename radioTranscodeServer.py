import asyncio
import websockets
import subprocess
import threading
import json

async def handle_client(websocket, path):
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
    ffmpeg_cmd = [
        'ffmpeg',
        '-i', stream_url,
        '-f', 'dfpwm',      # Output format DFPWM1
        '-ar', '48000',      # Sample rate
        '-ac', '1',          # Mono audio
        '-vn',               # No video
        'pipe:1'             # Output to stdout
    ]

    # Start the FFmpeg process with stderr captured
    ffmpeg_proc = subprocess.Popen(ffmpeg_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    try:
        while True:
            # Read DFPWM data from FFmpeg
            dfpwm_data = ffmpeg_proc.stdout.read(4096)
            if not dfpwm_data:
                # Read FFmpeg stderr
                stderr_output = ffmpeg_proc.stderr.read().decode()
                if stderr_output:
                    print(f"FFmpeg error: {stderr_output}")
                break

            # Send the DFPWM data over the WebSocket
            await websocket.send(dfpwm_data)
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected.")
    except Exception as e:
        print(f"Streaming error: {e}")
    finally:
        ffmpeg_proc.kill()

def start_server():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    server = websockets.serve(handle_client, '0.0.0.0', 8765)

    loop.run_until_complete(server)
    print("Streaming server started on port 8765.")
    loop.run_forever()

if __name__ == "__main__":
    start_server()
