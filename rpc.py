import struct
import json
import socket
import os
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

cid = "1512091160452137000"
port = 4444

def get_ipc_path():
    tmp = os.environ.get("XDG_RUNTIME_DIR") or os.environ.get("TMPDIR") or os.environ.get("TMP") or "/tmp"
    return f"{tmp}/discord-ipc-0"

class DiscordRPC:
    def __init__(self, client_id):
        self.client_id = client_id
        self.sock = None
        self.connected = False

    def _pack(self, op, data):
        payload = json.dumps(data).encode()
        return struct.pack("<II", op, len(payload)) + payload

    def connect(self):
        try:
            if os.name == "nt":
                path = r"\\.\pipe\discord-ipc-0"
                import ctypes
                self.pipe = open(path, "r+b", buffering=0)
                self.connected = True
                self._handshake()
                return True
            else:
                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                self.sock.connect(get_ipc_path())
                self.connected = True
                self._handshake()
                return True
        except Exception as e:
            print(f"rpc connect failed: {e}")
            self.connected = False
            return False

    def _read(self, n):
        if os.name == "nt":
            return self.pipe.read(n)
        buf = b""
        while len(buf) < n:
            buf += self.sock.recv(n - len(buf))
        return buf

    def _write(self, data):
        if os.name == "nt":
            self.pipe.write(data)
            self.pipe.flush()
        else:
            self.sock.sendall(data)

    def _handshake(self):
        self._write(self._pack(0, {"v": 1, "client_id": self.client_id}))
        op, length = struct.unpack("<II", self._read(8))
        resp = json.loads(self._read(length))
        if resp.get("evt") != "READY":
            raise Exception("discord rpc handshake failed")

    def set_activity(self, payload):
        if not self.connected:
            if not self.connect():
                return
        nonce = str(hash(json.dumps(payload)))
        data = {
            "cmd": "SET_ACTIVITY",
            "args": {
                "pid": os.getpid(),
                "activity": payload,
            },
            "nonce": nonce,
        }
        try:
            self._write(self._pack(1, data))
            op, length = struct.unpack("<II", self._read(8))
            self._read(length)
        except Exception as e:
            print(f"set_activity broke: {e}")
            self.connected = False

rpc = DiscordRPC(cid)
rpc.connect()

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/rpc":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            payload = json.loads(body)
            rpc.set_activity(payload)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
        except Exception as e:
            print(f"handler err: {e}")
            self.send_response(500)
            self.end_headers()

    def log_message(self, format, *args):
        pass

print(f"rpc bridge up on port {port}")
HTTPServer(("127.0.0.1", port), Handler).serve_forever()
