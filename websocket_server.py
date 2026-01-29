import asyncio
import subprocess
import websockets
import sys
import time

yolo_process = None  # Global variable to store process reference
yolo_task = None  # Store the task handling capture_yolo_output
clients = set()  # Store connected WebSocket clients

async def send_to_clients(message):
    """Send detected object names to all connected clients."""
    if clients:
        await asyncio.gather(*(client.send(message) for client in clients))

async def capture_yolo_output(process):
    """Read object detection output from yolo_camera.py and send response."""
    global yolo_process
    last_detection = ""  # Move outside the loop to persist across iterations

    try:
        while yolo_process:
            output = await process.stdout.readline()
            if not output:
                break

            output = output.decode().strip()
            if not output:
                continue

            if output != last_detection:
                print(output)
                time.sleep(2)
                await send_to_clients(output)
                last_detection = output
                
    except asyncio.CancelledError:
        print("YOLO output capture cancelled")
    finally:
        print("YOLO output capture ended")

async def start_yolo():
    global yolo_process, yolo_task
    if yolo_process is None:
        print("Starting YOLO camera script...")
        yolo_process = await asyncio.create_subprocess_exec(
            "python", "yolo_new.py", 
            stdout=asyncio.subprocess.PIPE, 
            stderr=asyncio.subprocess.DEVNULL
        )
        yolo_task = asyncio.create_task(capture_yolo_output(yolo_process))
    else:
        print("YOLO camera script is already running.")

async def stop_yolo():
    global yolo_process, yolo_task
    if yolo_process is not None:
        if yolo_process.returncode is None:
            print("Stopping YOLO camera script...")
            try:
                yolo_process.terminate()
                await yolo_process.wait()
            except ProcessLookupError:
                print("Process already exited, skipping terminate.")

        yolo_process = None

        if yolo_task:
            yolo_task.cancel()
            try:
                await yolo_task
            except asyncio.CancelledError:
                pass
        yolo_task = None
    else:
        print("No YOLO script is running.")

async def handle_client(websocket):
    """Handles WebSocket clients."""
    global yolo_task
    clients.add(websocket)
    print("Client connected")
    await websocket.send("connected")

    try:
        async for message in websocket:
            print(f"Received message: {message}")
            if message == 'Run':
                await start_yolo()
                await websocket.send("Executed Run")
            
            elif message == 'Stop':
                await stop_yolo()
                await websocket.send("Executed Stop")
            
            elif message == 'Quit':
                if yolo_process != None :
                    await stop_yolo()
                await websocket.send("Executed Quit")
                exit(0)
                return

    except websockets.exceptions.ConnectionClosedOK:
        print("Client disconnected")
    finally:
        clients.remove(websocket)

async def main():
    server = await websockets.serve(handle_client, "0.0.0.0", 8765)
    print("WebSocket started")
    
    await server.wait_closed()

if __name__ == "__main__":
    asyncio.run(main())
