import asyncio
import websockets
import subprocess
import json
from urllib.parse import urlparse

def is_youtube_url(url):
    parsed_url = urlparse(url)
    domain = parsed_url.netloc.lower()
    return 'youtube.com' in domain or 'youtu.be' in domain

async def get_media_url(stream_url):
    yt_dlp_cmd = [
        'yt-dlp',
        '-f', 'bestaudio',
        '--no-playlist',
        '--get-url',
        stream_url
    ]

    proc = await asyncio.create_subprocess_exec(
        *yt_dlp_cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await proc.communicate()

    if proc.returncode != 0:
        error_message = stderr.decode().strip()
        print(f"yt-dlp error: {error_message}")
        return None
    media_url = stdout.decode().strip()
    return media_url

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
    if is_youtube_url(stream_url):
        # Get the media URL from yt-dlp
        media_url = await get_media_url(stream_url)
        if not media_url:
            error_msg = 'Failed to get media URL from yt-dlp.'
            print(f"[{client_addr}] {error_msg}")
            await websocket.send(json.dumps({'error': error_msg}))
            return

        print(f"[{client_addr}] Retrieved media URL: {media_url}")

        # Now use FFmpeg to stream from the media_url
        ffmpeg_cmd = [
            'ffmpeg',
            '-i', media_url,
            '-f', 'dfpwm',
            '-ar', '48000',
            '-ac', '1',
            '-vn',
            'pipe:1'
        ]

        # Start the FFmpeg process asynchronously
        ffmpeg_proc = await asyncio.create_subprocess_exec(
            *ffmpeg_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
    else:
        # Use FFmpeg directly for other URLs
        ffmpeg_cmd = [
            'ffmpeg',
            '-i', stream_url,
            '-f', 'dfpwm',
            '-ar', '48000',
            '-ac', '1',
            '-vn',
            'pipe:1'
        ]

        # Start the FFmpeg process asynchronously
        ffmpeg_proc = await asyncio.create_subprocess_exec(
            *ffmpeg_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

    # Function to log FFmpeg stderr
    async def log_ffmpeg_stderr():
        while True:
            line = await ffmpeg_proc.stderr.readline()
            if not line:
                break
            print(f"[{client_addr}] FFmpeg stderr: {line.decode().strip()}")

    # Start the stderr logging task
    stderr_task = asyncio.create_task(log_ffmpeg_stderr())

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
        # Terminate FFmpeg process
        if ffmpeg_proc.returncode is None:
            ffmpeg_proc.kill()
            await ffmpeg_proc.wait()
            print(f"[{client_addr}] FFmpeg process terminated.")

        # Cancel the stderr logging task
        stderr_task.cancel()
        try:
            await stderr_task
        except asyncio.CancelledError:
            pass

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
