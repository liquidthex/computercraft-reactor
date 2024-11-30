import asyncio
import websockets
import subprocess
import json
from urllib.parse import urlparse

def is_youtube_url(url):
    parsed_url = urlparse(url)
    domain = parsed_url.netloc.lower()
    return 'youtube.com' in domain or 'youtu.be' in domain

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
        # Start yt-dlp process
        yt_dlp_cmd = [
            'yt-dlp',
            '-f', 'bestaudio',
            '--no-playlist',
            '-o', '-',  # Output to stdout
            stream_url
        ]
        yt_dlp_proc = await asyncio.create_subprocess_exec(
            *yt_dlp_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

        # Start ffmpeg process, reading from stdin
        ffmpeg_cmd = [
            'ffmpeg',
            '-i', 'pipe:0',     # Read from stdin
            '-f', 'dfpwm',
            '-ar', '48000',
            '-ac', '1',
            '-vn',
            'pipe:1'            # Output to stdout
        ]
        ffmpeg_proc = await asyncio.create_subprocess_exec(
            *ffmpeg_cmd,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

        # Function to pipe data from yt-dlp to ffmpeg
        async def pipe_data():
            try:
                while True:
                    data = await yt_dlp_proc.stdout.read(4096)
                    if not data:
                        break
                    ffmpeg_proc.stdin.write(data)
                    await ffmpeg_proc.stdin.drain()
                ffmpeg_proc.stdin.close()
            except Exception as e:
                print(f"[{client_addr}] Pipe error: {e}")

        # Start piping data
        pipe_task = asyncio.create_task(pipe_data())

        # Function to log yt-dlp stderr
        async def log_yt_dlp_stderr():
            while True:
                line = await yt_dlp_proc.stderr.readline()
                if not line:
                    break
                print(f"[{client_addr}] yt-dlp stderr: {line.decode().strip()}")

        # Start the yt-dlp stderr logging task
        yt_dlp_stderr_task = asyncio.create_task(log_yt_dlp_stderr())

    else:
        # Handle regular streaming URL
        ffmpeg_input = stream_url
        ffmpeg_cmd = [
            'ffmpeg',
            '-i', ffmpeg_input,
            '-f', 'dfpwm',
            '-ar', '48000',
            '-ac', '1',
            '-vn',
            'pipe:1'              # Output to stdout
        ]
        ffmpeg_proc = await asyncio.create_subprocess_exec(
            *ffmpeg_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

    # Function to log ffmpeg stderr
    async def log_ffmpeg_stderr():
        while True:
            line = await ffmpeg_proc.stderr.readline()
            if not line:
                break
            print(f"[{client_addr}] ffmpeg stderr: {line.decode().strip()}")

    # Start the ffmpeg stderr logging task
    ffmpeg_stderr_task = asyncio.create_task(log_ffmpeg_stderr())

    try:
        while True:
            dfpwm_data = await ffmpeg_proc.stdout.read(4096)
            if not dfpwm_data:
                print(f"[{client_addr}] FFmpeg has no more data.")
                break
            if websocket.closed:
                print(f"[{client_addr}] WebSocket closed unexpectedly.")
                break
            await websocket.send(dfpwm_data)
    except websockets.exceptions.ConnectionClosed:
        print(f"[{client_addr}] Client disconnected.")
    except Exception as e:
        print(f"[{client_addr}] Streaming error: {e}")
    finally:
        # Terminate ffmpeg process
        if ffmpeg_proc.returncode is None:
            ffmpeg_proc.kill()
            await ffmpeg_proc.wait()
            print(f"[{client_addr}] FFmpeg process terminated.")

        if is_youtube_url(stream_url):
            # Terminate yt-dlp process
            if yt_dlp_proc.returncode is None:
                yt_dlp_proc.kill()
                await yt_dlp_proc.wait()
                print(f"[{client_addr}] yt-dlp process terminated.")
            # Cancel tasks
            pipe_task.cancel()
            try:
                await pipe_task
            except asyncio.CancelledError:
                pass
            yt_dlp_stderr_task.cancel()
            try:
                await yt_dlp_stderr_task
            except asyncio.CancelledError:
                pass

        # Cancel ffmpeg stderr task
        ffmpeg_stderr_task.cancel()
        try:
            await ffmpeg_stderr_task
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
