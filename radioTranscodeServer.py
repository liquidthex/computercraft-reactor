import asyncio
import websockets
import subprocess
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

        client_addr = websocket.remote_address
        print(f"[{client_addr}] Client connected. Streaming: {stream_url}")

        # Start streaming the audio to the client
        await stream_audio(websocket, stream_url, client_addr)
    except websockets.exceptions.ConnectionClosed:
        print(f"[{client_addr}] Connection closed.")
    except Exception as e:
        print(f"[{client_addr}] Error: {e}")
    finally:
        if not websocket.closed:
            await websocket.close()
        print(f"[{client_addr}] Cleaned up client connection.")

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
                # Check for FFmpeg errors
                stderr_output = await ffmpeg_proc.stderr.read()
                stderr_output = stderr_output.decode()
                if stderr_output:
                    print(f"[{client_addr}] FFmpeg error: {stderr_output}")
                break

            # Send the DFPWM data over the WebSocket
            await websocket.send(dfpwm_data)
    except websockets.exceptions.ConnectionClosed:
        print(f"[{client_addr}] Client disconnected.")
    except Exception as e:
        print(f"[{client_addr}] Streaming error: {e}")
    finally:
        # Terminate the FFmpeg process
        ffmpeg_proc.kill()
        await ffmpeg_proc.wait()
        print(f"[{client_addr}] FFmpeg process terminated.")

async def main():
    print("Streaming server started on port 8765.")
    async with websockets.serve(handle_client, '0.0.0.0', 8765):
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())
