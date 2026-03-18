#!/usr/bin/env python3
"""BMB-System Conversation Logger

Background process that captures structured conversation events
and writes them to a markdown log file.

Usage:
    python3 conversation-logger.py <session_dir>

Reads from named pipe (FIFO): <session_dir>/log-pipe
Writes to: <session_dir>/conversation-log.md

Input format (one line per event):
    {timestamp}|{agent}|{type}|{content}

Types: QUESTION, ANSWER, DECISION, INSIGHT, CONTEXT

Shutdown: Send "SHUTDOWN" as content, or SIGTERM.
"""

import os
import signal
import sys
from datetime import datetime
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print("Usage: conversation-logger.py <session_dir>", file=sys.stderr)
        sys.exit(1)

    session_dir = Path(sys.argv[1])
    pipe_path = session_dir / "log-pipe"
    log_path = session_dir / "conversation-log.md"

    # Create FIFO if it doesn't exist
    if not pipe_path.exists():
        os.mkfifo(str(pipe_path))

    # Initialize log file
    if not log_path.exists():
        with open(log_path, "w") as f:
            f.write(f"# BMB Conversation Log\n")
            f.write(f"Session: {session_dir.name}\n")
            f.write(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M KST')}\n\n")
            f.write("---\n\n")

    # Graceful shutdown
    running = True

    def handle_signal(signum, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    TYPE_ICONS = {
        "QUESTION": "?",
        "ANSWER": ">",
        "DECISION": "!",
        "INSIGHT": "*",
        "CONTEXT": "#",
    }

    while running:
        try:
            # open blocks until a writer connects
            with open(pipe_path, "r") as fifo:
                for line in fifo:
                    line = line.strip()
                    if not line:
                        continue

                    # Check for shutdown signal
                    if "SHUTDOWN" in line:
                        running = False
                        break

                    # Parse: timestamp|agent|type|content
                    parts = line.split("|", 3)
                    if len(parts) < 4:
                        continue

                    timestamp, agent, event_type, content = parts
                    icon = TYPE_ICONS.get(event_type.upper(), "-")

                    with open(log_path, "a") as f:
                        f.write(f"### [{timestamp}] {agent} ({event_type})\n")
                        f.write(f"{icon} {content}\n\n")

        except OSError:
            # Pipe closed, reopen
            if running:
                continue
            break

    # Cleanup
    try:
        pipe_path.unlink(missing_ok=True)
    except Exception:
        pass

    print(f"Logger shutdown. Log saved to {log_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
