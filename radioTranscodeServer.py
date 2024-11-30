import asyncio
import websockets
import subprocess
import json
from urllib.parse import urlparse

def is_youtube_url(url):
    parsed_url = urlparse(url)
    domain = parsed_url.netloc.lower()
    return 'youtube.com' in domain or 'youtu.be' in domain

async def get_youtube_media_info(youtube_url):
    yt_dlp_cmd = [
        'yt-dlp',
        '-f', 'bestaudio',
        '--no-playlist',
        '--print-json',
        youtube_url
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

    try:
        media_info = json.loads(stdout.decode())
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}")
        return None

    return media_info

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
        # Handle YouTube URL
        media_info = await get_youtube_media_info(stream_url)
        if not media_info:
            error_msg = 'Failed to extract media info from YouTube link.'
            print(f"[{client_addr}] {error_msg}")
            await websocket.send(json.dumps({'error': error_msg}))
            return

        media_url = media_info.get('url')
        http_headers = media_info.get('http_headers', {})

        if not media_url:
            error_msg = 'No media URL found in media info.'
            print(f"[{client_addr}] {error_msg}")
            await websocket.send(json.dumps({'error': error_msg}))
            return

        print(f"[{client_addr}] Extracted media URL: {media_url}")

        # Prepare FFmpeg input options with headers
        input_options = []
        for header_name, header_value in http_headers.items():
            input_options.extend(['-headers', f"{header_name}: {header_value}\r\n"])

        ffmpeg_input = media_url

        ffmpeg_cmd = [
            'ffmpeg',
            '-re',                # Read input at native frame rate
            *input_options,
            '-i', ffmpeg_input,
            '-af', 'aresample=async=1',
            '-f', 'dfpwm',        # Output format
            '-ar', '48000',       # Sample rate
            '-ac', '1',           # Mono audio
            '-vn',                # No video
            'pipe:1'              # Output to stdout
        ]
    else:
        # Handle regular streaming URL
        ffmpeg_input = stream_url
        ffmpeg_cmd = [
            'ffmpeg',
            '-i', ffmpeg_input,
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

    # Function to log FFmpeg stderr (for debugging)
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
        # Terminate the FFmpeg process
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
