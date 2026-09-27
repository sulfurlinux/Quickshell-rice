"""Sample a running Quickshell process and its children; no extra dependencies."""

import argparse
import csv
import os
from pathlib import Path
import sys
import time


def processes():
    result = {}
    for directory in Path("/proc").iterdir():
        if not directory.name.isdecimal():
            continue
        try:
            stat = (directory / "stat").read_text()
            fields = stat[stat.rfind(")") + 2:].split()
            result[int(directory.name)] = {
                "name": stat[stat.find("(") + 1:stat.rfind(")")],
                "parent": int(fields[1]),
                "ticks": int(fields[11]) + int(fields[12]),
                "started": int(fields[19]),
                "rss": max(0, int(fields[21])),
            }
        except (OSError, ValueError, IndexError):
            continue  # Processes may exit while their metadata is being read.
    return result


def family(snapshot, pid):
    selected = {pid} if pid in snapshot else set()
    while True:
        children = {child for child, info in snapshot.items() if info["parent"] in selected}
        expanded = selected | children
        if expanded == selected:
            return {child: snapshot[child] for child in selected}
        selected = expanded


def sample_phase(pid, phase, seconds, writer, tick_rate, page_size, shell_started):
    previous = family(processes(), pid)
    previous_time = time.monotonic()
    deadline = previous_time + seconds
    start_ticks = float(Path("/proc/uptime").read_text().split()[0]) * tick_rate
    cpu_samples, memory_samples = [], []
    while previous_time < deadline:
        time.sleep(min(0.5, deadline - previous_time))
        snapshot = processes()
        if pid not in snapshot or snapshot[pid]["started"] != shell_started:
            raise RuntimeError("Quickshell exited or restarted; restart the profiler.")
        current = family(snapshot, pid)
        now = time.monotonic()
        elapsed = now - previous_time
        ticks = 0
        for child, info in current.items():
            old = previous.get(child)
            if old and old["started"] == info["started"]:
                ticks += max(0, info["ticks"] - old["ticks"])
            elif info["started"] >= start_ticks:
                ticks += info["ticks"]
        cpu = ticks / tick_rate / elapsed * 100
        memory = sum(info["rss"] for info in current.values()) * page_size / (1024 * 1024)
        writer.writerow([phase, round(seconds - max(0, deadline - now), 2),
                         round(cpu, 2), round(memory, 2), len(current)])
        cpu_samples.append(cpu)
        memory_samples.append(memory)
        previous, previous_time = current, now
    print(f"{phase}: CPU avg {sum(cpu_samples) / len(cpu_samples):.1f}%, "
          f"peak {max(cpu_samples):.1f}%; RSS peak {max(memory_samples):.1f} MiB", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, help="Quickshell PID; auto-detected if only one is running")
    parser.add_argument("--seconds", type=int, default=15, help="seconds per phase (default: 15)")
    parser.add_argument("--output", type=Path,
                        default=Path.home() / ".cache" / "quickshell-profile.csv")
    args = parser.parse_args()
    if not sys.platform.startswith("linux"):
        parser.error("Run this on the Linux desktop where Quickshell is running.")
    if args.seconds < 1:
        parser.error("--seconds must be at least 1")
    snapshot = processes()
    if args.pid is None:
        candidates = [pid for pid, info in snapshot.items()
                      if info["name"] in {"qs", "quickshell"}
                      and Path(f"/proc/{pid}").stat().st_uid == getattr(os, "getuid")()]
        if len(candidates) != 1:
            parser.error(f"Found {len(candidates)} Quickshell processes; specify --pid PID.")
        args.pid = candidates[0]
    if args.pid not in snapshot:
        parser.error("The selected process is not running.")
    sysconf = getattr(os, "sysconf")
    tick_rate = sysconf("SC_CLK_TCK")
    page_size = sysconf("SC_PAGE_SIZE")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    print(f"Profiling PID {args.pid}; CPU 100% means one fully used core.")
    print("Includes sampled child processes. RSS sums shared pages too; very short processes may be missed.")
    with args.output.open("w", newline="", encoding="utf-8") as output:
        writer = csv.writer(output)
        writer.writerow(["phase", "seconds", "cpu_percent", "rss_mib", "processes"])
        for phase, instruction in [
            ("idle", "Close the launcher and leave the desktop idle"),
            ("search", "After Enter, open the launcher and repeatedly type and erase app searches"),
            ("wallpaper", "After Enter, open /wallpaper and switch between several images"),
        ]:
            input(f"{instruction}. Press Enter to start {args.seconds} seconds: ")
            sample_phase(args.pid, phase, args.seconds, writer, tick_rate, page_size,
                         snapshot[args.pid]["started"])
            output.flush()
    print(f"Saved samples: {args.output}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, EOFError) as error:
        print(f"Profiler: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nProfiler stopped; completed samples remain in the output file.", file=sys.stderr)
        sys.exit(130)
