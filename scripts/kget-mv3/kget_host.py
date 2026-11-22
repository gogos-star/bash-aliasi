#!/usr/bin/env python3
import sys
import json
import subprocess

def get_message():
    raw_length = sys.stdin.buffer.read(4)
    if not raw_length:
        sys.exit(0)
    message_length = int.from_bytes(raw_length, byteorder=sys.byteorder)
    message = sys.stdin.buffer.read(message_length).decode('utf-8')
    return json.loads(message)

def send_message(content):
    encoded = json.dumps(content).encode('utf-8')
    sys.stdout.buffer.write(len(encoded).to_bytes(4, byteorder=sys.byteorder))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()

data = get_message()
url = data.get("url")
if url:
    subprocess.Popen(["/usr/bin/kget", url], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    send_message({"status": "ok"})
