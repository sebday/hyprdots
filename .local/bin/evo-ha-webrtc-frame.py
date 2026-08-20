#!/usr/bin/env python3
"""Capture a single JPEG frame from a Home Assistant WebRTC camera (e.g. Nest)."""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import aiohttp
from aiortc import RTCPeerConnection, RTCSessionDescription
from av import VideoFrame


def fix_google_sdp(sdp: str) -> str:
    lines = []
    for line in sdp.splitlines():
        if line.startswith("a=candidate: "):
            line = "a=candidate:0 " + line[len("a=candidate: "):]
        lines.append(line)
    return "\r\n".join(lines)


def ha_ws_url(base_url: str) -> str:
    parsed = urlparse(base_url)
    scheme = "wss" if parsed.scheme == "https" else "ws"
    host = parsed.netloc or parsed.path
    return f"{scheme}://{host}/api/websocket"


def is_placeholder(path: Path) -> bool:
    if not path.is_file():
        return False
    return path.stat().st_size == 2689


async def wait_for_frame(track, timeout: float) -> VideoFrame:
    async def _recv() -> VideoFrame:
        while True:
            frame = await track.recv()
            if isinstance(frame, VideoFrame) and frame.width > 0 and frame.height > 0:
                return frame

    return await asyncio.wait_for(_recv(), timeout=timeout)


async def capture_frame(
    base_url: str,
    token: str,
    entity_id: str,
    output_path: Path,
    timeout: float,
) -> None:
    ws_url = ha_ws_url(base_url)
    msg_id = 10
    session_id: str | None = None
    answer_future: asyncio.Future[str] = asyncio.get_running_loop().create_future()

    pc = RTCPeerConnection()
    pc.addTransceiver("audio", direction="recvonly")
    pc.addTransceiver("video", direction="recvonly")
    pc.createDataChannel("dataSendChannel")

    video_track = None

    @pc.on("track")
    def on_track(track) -> None:
        nonlocal video_track
        if track.kind == "video" and video_track is None:
            video_track = track

    @pc.on("icecandidate")
    def on_icecandidate(candidate) -> None:
        if candidate is None or session_id is None:
            return
        asyncio.create_task(send_candidate(candidate))

    async def send_candidate(candidate) -> None:
        assert session is not None
        parts = candidate.candidate.split()
        if len(parts) < 8:
            return
        payload = {
            "id": msg_id + 1,
            "type": "camera/webrtc/candidate",
            "entity_id": entity_id,
            "session_id": session_id,
            "candidate": {
                "candidate": candidate.candidate,
                "sdpMLineIndex": candidate.sdpMLineIndex,
                "sdpMid": candidate.sdpMid,
            },
        }
        await ws.send_json(payload)

    offer = await pc.createOffer()
    await pc.setLocalDescription(offer)

    session: aiohttp.ClientSession | None = None
    ws: aiohttp.ClientWebSocketResponse | None = None

    try:
        session = aiohttp.ClientSession()
        ws = await session.ws_connect(ws_url, heartbeat=30)

        auth_required = await ws.receive_json()
        if auth_required.get("type") != "auth_required":
            raise RuntimeError("unexpected websocket greeting")

        await ws.send_json({"type": "auth", "access_token": token})
        auth_ok = await ws.receive_json()
        if auth_ok.get("type") != "auth_ok":
            raise RuntimeError("home assistant websocket auth failed")

        await ws.send_json(
            {
                "id": msg_id,
                "type": "camera/webrtc/offer",
                "entity_id": entity_id,
                "offer": pc.localDescription.sdp,
            }
        )

        deadline = asyncio.get_running_loop().time() + timeout
        while asyncio.get_running_loop().time() < deadline:
            remaining = deadline - asyncio.get_running_loop().time()
            if remaining <= 0:
                break
            raw = await asyncio.wait_for(ws.receive(), timeout=remaining)
            if raw.type != aiohttp.WSMsgType.TEXT:
                continue
            message = json.loads(raw.data)
            if message.get("id") != msg_id:
                continue

            if message.get("type") == "event":
                event = message.get("event") or {}
                event_type = event.get("type")
                if event_type == "session":
                    session_id = str(event.get("session_id") or "")
                elif event_type == "answer" and not answer_future.done():
                    answer_future.set_result(str(event.get("answer") or ""))
                elif event_type == "error":
                    raise RuntimeError(
                        str(event.get("message") or event.get("code") or "webrtc error")
                    )
            elif message.get("type") == "result" and message.get("success") is False:
                raise RuntimeError(str(message.get("error") or "webrtc offer failed"))

        if not answer_future.done():
            raise RuntimeError("timed out waiting for webrtc answer")

        answer_sdp = fix_google_sdp(await answer_future)
        await pc.setRemoteDescription(
            RTCSessionDescription(sdp=answer_sdp, type="answer")
        )

        for _ in range(40):
            if video_track is not None:
                break
            await asyncio.sleep(0.1)
        if video_track is None:
            raise RuntimeError("no video track received")

        frame = await wait_for_frame(video_track, timeout=timeout)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        tmp = output_path.with_suffix(output_path.suffix + ".tmp")
        frame.to_image().save(tmp)
        tmp.replace(output_path)
    finally:
        if ws is not None and not ws.closed:
            await ws.close()
        if session is not None:
            await session.close()
        await pc.close()


def load_secrets() -> tuple[str, str]:
    url = os.environ.get("HOME_ASSISTANT_URL", "").rstrip("/")
    token = os.environ.get("HOME_ASSISTANT_TOKEN", "")
    secrets = Path.home() / ".local/share/evoshell/secrets.env"
    if secrets.is_file():
        for line in secrets.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip("'").strip('"')
            if key == "HOME_ASSISTANT_URL" and not url:
                url = value.rstrip("/")
            if key == "HOME_ASSISTANT_TOKEN" and not token:
                token = value
    if not url or not token:
        raise SystemExit("HOME_ASSISTANT_URL and HOME_ASSISTANT_TOKEN are required")
    return url, token


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("entity_id")
    parser.add_argument("output")
    parser.add_argument("--timeout", type=float, default=20.0)
    args = parser.parse_args()

    url, token = load_secrets()
    output = Path(args.output)

    try:
        asyncio.run(
            capture_frame(url, token, args.entity_id, output, timeout=args.timeout)
        )
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if not output.is_file() or output.stat().st_size < 4096:
        print("captured frame too small", file=sys.stderr)
        return 1
    if is_placeholder(output):
        print("captured nest placeholder", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
