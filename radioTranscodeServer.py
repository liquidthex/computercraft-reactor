import asyncio
import websockets
import subprocess
import json

async def handle_client(websocket, path):
    client_addr = websocket.remote_address
    try:
        message = await websocket.recv()
        request = json.loads(message)
        stream_url = request.get('stream_url')

        if not stream_url:
            await websocket.send(json.dumps({'error': 'No stream URL provided.'}))
            return

        print(f"[{client_addr}] Client connected. Streaming: {stream_url}")

        # Start streaming the audio to the client
        await stream_audio(websocket, stream_url, client_addr)
    except websockets.exceptions.ConnectionClosed:
        print(f"[{client_addr}] Connection closed during initial handshake.")
    except Exception as e:
        print(f"[{client_addr}] Error during initial handshake: {e}")

async def stream_audio(websocket, stream_url, client_addr):
    ffmpeg_cmd = [
        'ffmpeg',
        '-i', stream_url,
        '-f', 'dfpwm',        # Output format
        '-ar', '48000',       # Sample rate
        '-ac', '1',           # Mono audio
        '-vn',                # No video
        'pipe:1'              # Output to stdout
    ]

    # Start the FFmpeg process asynchronously
    ffmpeg_proc = await asyncio.create_subprocess_exec(
        *ffmpeg_cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )

    try:
        while True:
            # Read DFPWM data from FFmpeg asynchronously
            dfpwm_data = await ffmpeg_proc.stdout.read(4096)
            if not dfpwm_data:
                # FFmpeg has no more data to send
                print(f"[{client_addr}] FFmpeg has no more data.")
                break

            # Check if the websocket is still open before sending
            if websocket.closed:
                print(f"[{client_addr}] WebSocket closed unexpectedly.")
                break

            # Send the DFPWM data over the WebSocket
            await websocket.send(dfpwm_data)
    except websockets.exceptions.ConnectionClosed:
        print(f"[{client_addr}] Client disconnected.")
    except Exception as e:
        print(f"[{client_addr}] Streaming error: {e}")
    finally:
        # Terminate the FFmpeg process
        if ffmpeg_proc.returncode is None:
            ffmpeg_proc.kill()
            await ffmpeg_proc.wait()
            print(f"[{client_addr}] FFmpeg process terminated.")

        # Close the WebSocket if it's still open
        if not websocket.closed:
            await websocket.close()
            print(f"[{client_addr}] WebSocket closed.")

async def main():
    print("Streaming server started on port 8765.")
    async with websockets.serve(handle_client, '0.0.0.0', 8765):
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())
