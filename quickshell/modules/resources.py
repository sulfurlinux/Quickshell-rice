#!/usr/bin/env python3
"""Stream Linux CPU and memory usage for all bars."""
import json
from pathlib import Path
import sys
import time


def cpu_sample():
    fields = Path("/proc/stat").read_text().splitlines()[0].split()[1:]
    values = [int(value) for value in fields[:8]]
    return sum(values), values[3] + values[4]


def main():
    try:
        previous_total, previous_idle = cpu_sample()
        time.sleep(0.5)
        while True:
            total, idle = cpu_sample()
            elapsed = total - previous_total
            cpu = 100 * (1 - (idle - previous_idle) / elapsed) if elapsed > 0 else 0
            previous_total, previous_idle = total, idle
            memory = {}
            for line in Path("/proc/meminfo").read_text().splitlines():
                name, value = line.split(":", 1)
                memory[name] = int(value.split()[0]) * 1024
            available = memory.get("MemAvailable", memory.get("MemFree", 0))
            memory_total = memory["MemTotal"]
            used = memory_total - available
            print(json.dumps({
                "cpu": round(max(0, min(100, cpu))),
                "memory": round(100 * used / memory_total),
                "memoryUsedGiB": round(used / 1024 ** 3, 1),
                "memoryTotalGiB": round(memory_total / 1024 ** 3, 1),
            }), flush=True)
            time.sleep(2)
    except (OSError, ValueError, KeyError, ZeroDivisionError) as error:
        print(f"Resource monitor: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
