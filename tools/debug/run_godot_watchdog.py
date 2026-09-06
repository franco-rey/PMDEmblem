from __future__ import annotations

import argparse
import os
import selectors
import signal
import subprocess
import sys
import time
from pathlib import Path


DEFAULT_GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a Godot script with wall-clock and idle timeouts.")
    parser.add_argument("--godot", default=DEFAULT_GODOT)
    parser.add_argument("--project", default=".")
    parser.add_argument("--script")
    parser.add_argument("--headless", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--idle-timeout", type=float, default=30.0)
    parser.add_argument("--label", default="")
    parser.add_argument("passthrough_args", nargs=argparse.REMAINDER)
    return parser.parse_args()


def kill_process_group(proc: subprocess.Popen[str]) -> None:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def main() -> int:
    args = parse_args()
    passthrough_args = args.passthrough_args
    if passthrough_args and passthrough_args[0] == "--":
        passthrough_args = passthrough_args[1:]

    cmd = [args.godot]
    if args.headless:
        cmd.append("--headless")
    cmd.extend(["--path", args.project])
    if args.script:
        cmd.extend(["--script", args.script])
        if passthrough_args:
            cmd.extend(["--", *passthrough_args])
    else:
        cmd.extend(passthrough_args)
    label = args.label or (Path(args.script).name if args.script else "godot")
    print(f"watchdog: start label={label} timeout={args.timeout}s idle_timeout={args.idle_timeout}s")
    print("watchdog: command=" + " ".join(cmd))

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        start_new_session=True,
    )
    assert proc.stdout is not None

    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    started = time.monotonic()
    last_output = started
    captured: list[str] = []
    killed_reason = ""

    while True:
        now = time.monotonic()
        if args.timeout > 0 and now - started > args.timeout:
            killed_reason = f"timeout after {args.timeout:.1f}s"
            kill_process_group(proc)
            break
        if args.idle_timeout > 0 and now - last_output > args.idle_timeout:
            killed_reason = f"idle timeout after {args.idle_timeout:.1f}s"
            kill_process_group(proc)
            break

        events = selector.select(timeout=0.25)
        for key, _mask in events:
            line = key.fileobj.readline()
            if line:
                last_output = time.monotonic()
                captured.append(line)
                sys.stdout.write(line)
                sys.stdout.flush()

        if proc.poll() is not None:
            remaining = proc.stdout.read()
            if remaining:
                captured.append(remaining)
                sys.stdout.write(remaining)
            break

    elapsed = time.monotonic() - started
    if killed_reason:
        print(f"watchdog: killed label={label} reason={killed_reason} elapsed={elapsed:.2f}s")
        print(f"watchdog: recent output:\n{''.join(captured[-80:])}")
        return 124

    code = proc.returncode if proc.returncode is not None else 1
    print(f"watchdog: exit label={label} code={code} elapsed={elapsed:.2f}s")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
