#!/usr/bin/env python
import sys, io, os, subprocess

# emulate `command | tee /dev/stderr | command` style logging injection into pipelines
# (for non-tty / headless scripting workflows where normal /dev/stderr unavailable)
# supports /dev/stderr and /dev/stdout and otherwise forwards to tee.exe
# -- humbletim 2024.03.15

[ sys_stdin,  sys_stdout, sys_stderr] = [
  getattr(sys.stdin, 'buffer', sys.stdin),
  getattr(sys.stdout, 'buffer', sys.stdout),
  getattr(sys.stderr, 'buffer', sys.stderr),
]
stream_map = [
    [sys_stdout, os.environ.get('TEE', '/usr/bin/tee') ],  # Default/fallback
    [sys_stdout, '/dev/stdout'],  # For troubleshooting tty issues
    [sys_stdout, '/proc/self/fd/1'],
    [sys_stderr, '/dev/stderr'],
    [sys_stderr, '/proc/self/fd/2'],
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

data=True
while data:
    #print("fileno sys_stdin", sys_stdin.fileno())
    try:
      data = sys_stdin.readline() or os.read(sys_stdin.fileno(), 1024)
    except KeyboardInterrupt: sys.exit(-1)
    for stream in write_streams:
        stream.write(data)
        stream.flush()
