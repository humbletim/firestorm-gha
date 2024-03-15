#!/usr/bin/env python3
import sys, io, os, subprocess

# emulate `command | tee /dev/stderr | command` style logging injection into pipelines
# (for non-tty / headless scripting workflows where normal /dev/stderr unavailable)
# supports /dev/stderr and /dev/stdout and otherwise forwards to tee.exe
# -- humbletim 2024.03.15

stream_map = [
    [sys.stdout.buffer, 'C:/Program Files/Git/usr/bin/tee.exe'],  # Default/fallback 
    [sys.stdout.buffer, '/dev/stdout'],  # For troubleshooting tty issues
    [sys.stderr.buffer, '/dev/stderr'], 
]

forward = stream_map[0]

# accumulate destinational argument buckets
for arg in sys.argv[1:]:
    entry = next((v for v in stream_map if arg.endswith(v[1])), stream_map[0])
    entry.append(arg)

if stream_map[0][2:]:
    # forward non-/dev/stdout non-/dev/stderr arguments to actual tee.exe
    stream_map[0][0] = subprocess.Popen(stream_map[0][1:], stdin=subprocess.PIPE).stdin
else:
    # activate local sys.stdin => sys.stdout copying instead of tee.exe
    stream_map[0].append(True)

write_streams = [v[0] for v in stream_map if v[2:]]

# print(write_streams)

while (data := sys.stdin.buffer.readline() or os.read(0, 1024)):
    for stream in write_streams:
        stream.write(data)
        stream.flush()
