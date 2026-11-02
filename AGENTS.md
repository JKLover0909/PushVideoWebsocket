# AGENTS.md

## Overview
Streams video frames over WebSocket to a Flutter mobile client, with a YOLO-style defect detection model ("khuyet" = defect) for the demo videos. Python WebSocket server + Flutter app (`websocket_app/`) + an ngrok tunnel to reach the server from a phone.

## Layout
- `video_websocket_server.py` — `VideoStreamServer`: reads a video file and broadcasts frames to connected clients on `ws://0.0.0.0:8765`.
- `Code.ipynb` — experiments (frame sending, model inference).
- `best.pt` / `best.onnx` — trained detection model (PyTorch / ONNX export).
- `khuyet1.mp4`, `khuyet2.mp4` — demo videos.
- `websocket_app/` — Flutter app (`lib/main.dart` connects to the server via `wss://<ngrok-host>/`; the ngrok URL is hard-coded and ephemeral — update it for each tunnel).
- `ngrok`, `ngrok-stable-linux-amd64.zip`, `ngrok.log`, `nohup.out` — tunnel binary/logs, untracked and gitignored.

## Commands
- Server: `python video_websocket_server.py <video_path>` (needs `websockets`, `opencv-python`, model deps).
- Tunnel: `ngrok http 8765` (install ngrok separately; set your own authtoken locally, never in the repo).
- App: `cd websocket_app && flutter pub get && flutter run`.

## Rules
- Never commit ngrok authtokens, tunnel URLs of live sessions, logs or the ngrok binary.
- Do not commit large new media/model files without being asked.
- Keep the WebSocket port (8765) and message format in sync between server and app.
