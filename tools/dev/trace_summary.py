#!/usr/bin/env python3
"""Summarise a Seamless Co-op probe trace (JSONL) into a readable timeline.

Usage:
    python tools/dev/trace_summary.py <trace.jsonl> [--out timeline.txt] [--max-calls-per-method 40]
        [--skip REGEX] [--only REGEX]

Output: a chronological timeline of marks, state changes (only changed keys), method calls (noisy methods are
truncated after N calls) and first appearances of network packet types, followed by statistics.
The trace format is written by re/probes/seamless_probe.lua.
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sys
from pathlib import Path


def fmt_args(args):
    if not args:
        return ""
    return ", ".join("null" if a is None else str(a) for a in args)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("trace", type=Path)
    ap.add_argument("--out", type=Path, help="write the timeline here (default: <trace>.timeline.txt)")
    ap.add_argument("--max-calls-per-method", type=int, default=40,
                    help="after this many calls of the same method, further calls are only counted")
    ap.add_argument("--skip", default=None, help="regex of method labels to leave out of the timeline")
    ap.add_argument("--only", default=None, help="regex: only show calls whose label matches")
    ns = ap.parse_args()

    skip = re.compile(ns.skip) if ns.skip else None
    only = re.compile(ns.only) if ns.only else None
    out_path = ns.out or ns.trace.with_suffix(".timeline.txt")

    records = []
    bad = 0
    with ns.trace.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                bad += 1

    calls = collections.Counter()
    shown = collections.Counter()
    packets_seen = set()
    census_total = collections.Counter()
    prev_state: dict = {}
    lines_out = []
    header = None

    for r in records:
        k = r.get("k")
        t = r.get("t", 0.0)
        ts = f"{t:9.3f}"
        if k == "start":
            header = r
            lines_out.append(f"{ts}  START probe v{r.get('v')} game={r.get('game')} tdb={r.get('tdb')} "
                             f"hooks_ok={r.get('hooks_ok')} failed={r.get('hooks_failed')} missing={r.get('missing')}")
        elif k == "mark":
            label = f" '{r.get('label')}'" if r.get("label") else ""
            lines_out.append(f"{ts}  ==== MARK #{r.get('n')} ({r.get('src')}){label} ====")
        elif k == "state":
            s = r.get("s", {})
            changed = {key: val for key, val in s.items() if prev_state.get(key, "<absent>") != val}
            gone = [key for key in prev_state if key not in s]
            if changed or gone:
                parts = [f"{key}={val}" for key, val in sorted(changed.items())]
                parts += [f"{key}=<gone>" for key in gone]
                lines_out.append(f"{ts}  STATE " + " ".join(parts))
            prev_state = s
        elif k == "call":
            m = r.get("m", "?")
            calls[m] += 1
            if skip and skip.search(m):
                continue
            if only and not only.search(m):
                continue
            shown[m] += 1
            if shown[m] <= ns.max_calls_per_method:
                lines_out.append(f"{ts}  call {m}  [{fmt_args(r.get('a'))}]")
            elif shown[m] == ns.max_calls_per_method + 1:
                lines_out.append(f"{ts}  call {m}  ... (further calls only counted)")
        elif k == "muted":
            lines_out.append(f"{ts}  muted {r.get('m')} (rate {r.get('rate')}/s)")
        elif k == "census":
            for key, n in (r.get("d") or {}).items():
                census_total[key] += n
                if key not in packets_seen:
                    packets_seen.add(key)
                    lines_out.append(f"{ts}  packet-type first seen: {key}")
        elif k in ("paused", "resumed", "stop"):
            lines_out.append(f"{ts}  {k.upper()}")

    stats = ["", "=== Statistics ===", f"records: {len(records)} (unparseable: {bad})"]
    if header:
        stats.append(f"probe: v{header.get('v')}  hooks_ok={header.get('hooks_ok')}")
    stats.append("calls per method:")
    for m, n in calls.most_common():
        stats.append(f"  {n:7d}  {m}")
    stats.append("network packet census (method|session type|packet type):")
    for key, n in census_total.most_common():
        stats.append(f"  {n:7d}  {key}")

    out_path.write_text("\n".join(lines_out + stats) + "\n", encoding="utf-8")
    print(f"{ns.trace.name}: {len(records)} records, {len(calls)} distinct methods called, "
          f"{sum(calls.values())} calls, {len(packets_seen)} packet types -> {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
