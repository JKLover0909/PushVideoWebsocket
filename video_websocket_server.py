#!/usr/bin/env python3
"""
WebSocket Video Streaming Server
Stream video frames qua WebSocket để các ứng dụng khác có thể kết nối
"""

import asyncio
import websockets
import cv2
import base64
import json
import threading
import time
import os

class VideoStreamServer:
    def __init__(self, video_path, host="0.0.0.0", port=8765):
        self.video_path = video_path
        self.host = host
        self.port = port
        self.clients = set()
        self.is_streaming = False
        self.current_frame = None
        self.loop = None
    
    async def register_client(self, websocket):
        self.clients.add(websocket)
        print(f"✅ Client mới: {websocket.remote_address} | Tổng clients: {len(self.clients)}")
        if self.current_frame:
            try:
                await websocket.send(self.current_frame)
            except:
                pass
    
    async def unregister_client(self, websocket):
        self.clients.discard(websocket)
        print(f"❌ Client ngắt kết nối | Còn lại: {len(self.clients)}")
    
    async def broadcast_frame(self, frame_data):
        if not self.clients:
            return
        self.current_frame = frame_data
        disconnected = []
        for client in self.clients.copy():
            try:
                await client.send(frame_data)
            except websockets.exceptions.ConnectionClosed:
                disconnected.append(client)
            except Exception as e:
                print(f"⚠️ Lỗi gửi data: {e}")
                disconnected.append(client)
        for client in disconnected:
            await self.unregister_client(client)
    
    def video_capture_thread(self):
        cap = cv2.VideoCapture(self.video_path)
        if not cap.isOpened():
            print(f"❌ Không thể mở video: {self.video_path}")
            return
        fps = int(cap.get(cv2.CAP_PROP_FPS)) or 30
        frame_delay = 1.0 / fps
        print(f"📹 Video info: {fps} FPS")
        frame_count = 0
        try:
            while self.is_streaming:
                ret, frame = cap.read()
                if not ret:
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    frame_count = 0
                    print("🔄 Video kết thúc, lặp lại từ đầu...")
                    continue
                frame = cv2.resize(frame, (640, 480))
                encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 80]
                _, buffer = cv2.imencode('.jpg', frame, encode_param)
                frame_base64 = base64.b64encode(buffer).decode('utf-8')
                message = json.dumps({
                    "type": "video_frame",
                    "data": frame_base64,
                    "frame": frame_count,
                    "timestamp": time.time(),
                    "clients": len(self.clients)
                })
                if self.loop:
                    asyncio.run_coroutine_threadsafe(
                        self.broadcast_frame(message), 
                        self.loop
                    )
                frame_count += 1
                time.sleep(frame_delay)
        except Exception as e:
            print(f"❌ Lỗi video capture: {e}")
        finally:
            cap.release()
            print("📹 Video capture stopped")
    
    async def handle_client(self, websocket, path):
        await self.register_client(websocket)
        try:
            welcome = json.dumps({
                "type": "welcome",
                "message": "Kết nối WebSocket thành công!",
                "server": f"ws://{self.host}:{self.port}"
            })
            await websocket.send(welcome)
            async for message in websocket:
                try:
                    data = json.loads(message)
                    print(f"📨 Nhận từ client: {data}")
                    if data.get("type") == "ping":
                        pong = json.dumps({"type": "pong", "timestamp": time.time()})
                        await websocket.send(pong)
                except json.JSONDecodeError:
                    print(f"⚠️ Invalid JSON từ client: {message}")
        except websockets.exceptions.ConnectionClosed:
            print("🔌 Client ngắt kết nối")
        except Exception as e:
            print(f"❌ Lỗi handle client: {e}")
        finally:
            await self.unregister_client(websocket)
    
    async def start_server(self):
        self.loop = asyncio.get_event_loop()
        print(f"🚀 Khởi động WebSocket server...")
        print(f"📍 URL: ws://{self.host}:{self.port}")
        print(f"🎥 Video: {self.video_path}")
        if not os.path.exists(self.video_path):
            print(f"❌ File video không tồn tại: {self.video_path}")
            return
        self.is_streaming = True
        video_thread = threading.Thread(target=self.video_capture_thread)
        video_thread.daemon = True
        video_thread.start()
        async with websockets.serve(self.handle_client, self.host, self.port):
            print(f"✅ Server đang chạy tại ws://{self.host}:{self.port}")
            print("📱 Clients có thể kết nối để nhận video stream")
            print("⏹️ Nhấn Ctrl+C để dừng server")
            try:
                await asyncio.Future()  # Chạy mãi mãi
            except KeyboardInterrupt:
                print("\n🛑 Đang dừng server...")
                self.is_streaming = False
                print("✅ Server đã dừng")

def main():
    video_path = "/home/ubuntu/vnet/PushVideoWebsocket/khuyet2.mp4"
    server = VideoStreamServer(video_path=video_path, host="0.0.0.0", port=8765)
    try:
        asyncio.run(server.start_server())
    except KeyboardInterrupt:
        print("\n👋 Đã dừng server!")

if __name__ == "__main__":
    main()
