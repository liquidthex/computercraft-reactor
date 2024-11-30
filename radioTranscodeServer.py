import asyncio
import websockets
import subprocess
import shlex
import json
import re

async def get_youtube_hls_url(url):
    cmd = [
        'yt-dlp',
        '-g',
        '-f', 'bestaudio[protocol^=m3u8]',
        url
    ]
    process = await asyncio.create_subprocess_exec(
        *cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    stdout, stderr = await process.communicate()
    if process.returncode != 0:
        print(f"yt-dlp error: {stderr.decode()}")
        return None
    hls_url = stdout.decode().strip()
    return hls_url

async def stream_audio(websocket, url, client_addr):
    if "youtube.com" in url or "youtu.be" in url:
        hls_url = await get_youtube_hls_url(url)
        if not hls_url:
            await websocket.send("Error: Could not extract HLS URL from YouTube link.")
            return
        print(f"[{client_addr}] Extracted HLS URL: {hls_url}")
        ffmpeg_cmd = f"ffmpeg -re -i \"{hls_url}\" -f dfpwm -ar 48000 -ac 1 pipe:1"
    else:
        ffmpeg_cmd = f"ffmpeg -re -i \"{url}\" -f dfpwm -ar 48000 -ac 1 pipe:1"

    print(f"[{client_addr}] Running command: {ffmpeg_cmd}")
    process = await asyncio.create_subprocess_shell(
        ffmpeg_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    async def send_audio():
        try:
            while True:
                data = await process.stdout.read(4096)
                if not data:
                    print(f"[{client_addr}] FFmpeg has no more data.")
                    break
                await websocket.send(data)
        except websockets.exceptions.ConnectionClosedError:
            print(f"[{client_addr}] WebSocket connection closed unexpectedly.")
        finally:
            process.terminate()

    async def log_stderr():
        while True:
            line = await process.stderr.readline()
            if not line:
                break
            print(f"[{client_addr}] FFmpeg stderr: {line.decode().strip()}")

    send_task = asyncio.create_task(send_audio())
    stderr_task = asyncio.create_task(log_stderr())

    await send_task
    await process.wait()
    stderr_task.cancel()
    try:
        await stderr_task
    except asyncio.CancelledError:
        pass

async def handle_client(websocket, path):
    client_addr = websocket.remote_address
    print(f"[{client_addr}] Client connected.")
    try:
        url = await websocket.recv()
        print(f"[{client_addr}] Streaming: {url}")
        await stream_audio(websocket, url, client_addr)
    except websockets.exceptions.ConnectionClosedError:
        print(f"[{client_addr}] Client disconnected abruptly.")
    except Exception as e:
        print(f"[{client_addr}] Error: {e}")
    finally:
        if not websocket.closed:
            await websocket.close()
            print(f"[{client_addr}] WebSocket closed.")

async def main():
    print("Streaming server started on port 8765.")
    async with websockets.serve(handle_client, '0.0.0.0', 8765):
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())
