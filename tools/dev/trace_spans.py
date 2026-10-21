#!/usr/bin/env python3
"""Extract mission / hunting-quest / cutscene spans from a Seamless Co-op probe trace (JSONL).

Usage:
    python tools/dev/trace_spans.py <trace.jsonl> [--mission-names <enum-dump.hpp>]

Prints (Markdown):
  * main missions: when each became active and when it was cleared, and whether a hunting quest ran inside it
  * hunting quests: accept (gate) -> engage (requestAttackQuestStart) -> hunt objective cleared, session creation
  * cutscenes: timeline event id, start/end, duration, skipped or watched
  * dialogue choices, party-sync (Environment Link) info changes, halt warnings
Relies on method labels written by re/probes/seamless_probe.lua (v0.1.1+).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def load(path: Path):
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if line:
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue


def enum_names(dump: Path | None, namespace: str, enum: str) -> dict[int, str]:
    if not dump or not dump.exists():
        return {}
    text = dump.read_text(encoding="utf-8", errors="replace")
    m = re.search(rf"namespace {re.escape(namespace)} {{\s*enum {re.escape(enum)} {{(.*?)}};", text, re.S)
    if not m:
        return {}
    return {int(v): k for k, v in re.findall(r"(\w+) = (-?\d+),", m.group(1))}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("trace", type=Path)
    ap.add_argument("--mission-names", type=Path, help="Enums_Internal.hpp from the REFramework dump (optional)")
    ns = ap.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    mnames = enum_names(ns.mission_names, "app::MissionIDList", "ID")
    tnames = enum_names(ns.mission_names, "app::TimelineEventDefine", "ID")

    def mname(i):
        return mnames.get(i, f"#{i}").replace("MISSION_", "")

    active = None            # (mission id, t)
    missions = []            # dicts
    quests = []
    cutscenes = []
    open_cut = {}
    skips_pending = 0
    choices, sync_info, halts = [], [], []
    state_prev = {}

    for r in load(ns.trace):
        k, t = r.get("k"), r.get("t", 0.0)
        if k == "state":
            s = r.get("s", {})
            for key in ("canPartySyncHere", "keepDrawOthers", "partySyncProgress", "progress", "plControls"):
                if key in s and state_prev.get(key) != s[key] and key in state_prev:
                    sync_info.append((t, key, state_prev.get(key), s[key]))
            state_prev = s
            continue
        if k != "call":
            continue
        m, a = r.get("m", ""), r.get("a") or []
        if m.startswith("MissionManager.updateMissionManageIDToActiveMission("):
            mid = a[0] if a else None
            if active is None or active[0] != mid:
                if active is not None:
                    missions.append({"id": active[0], "start": active[1], "end": None, "quest": False})
                active = (mid, t)
        elif m.startswith("MissionController.setMissionClear("):
            if active is not None:
                q = any(qq["mission"] == active[0] for qq in quests)
                missions.append({"id": active[0], "start": active[1], "end": t, "quest": q})
                active = None
        elif m.startswith("cQuestDirector.acceptQuest("):
            quests.append({"mission": active[0] if active else None, "accept": t, "engage": None, "end": None,
                           "session": False})
        elif m.startswith("NetworkRequestManager.createSession(") and quests and a and a[0] == 2:
            quests[-1]["session"] = True
        elif m.startswith("MissionManager.requestAttackQuestStart("):
            if quests and quests[-1]["engage"] is None and quests[-1]["end"] is None:
                quests[-1]["engage"] = t
            else:
                quests.append({"mission": active[0] if active else None, "accept": None, "engage": t, "end": None,
                               "session": False, "engage_only": True})
        elif m.startswith("MissionController.clearQuestObjective("):
            for q in reversed(quests):
                if q["end"] is None and q.get("accept") is not None:
                    q["end"] = t
                    q["objective"] = a[0] if a else None
                    break
        elif m.startswith("DemoMediator.onPlayStartTimeline("):
            eid = a[0] if a else None
            open_cut[eid] = {"id": eid, "start": t, "skips": 0, "mission": active[0] if active else None}
            skips_pending = 0
        elif m.startswith("DemoMediator.requestSkip("):
            for c in open_cut.values():
                c["skips"] += 1
        elif m.startswith("DemoMediator.onPlayEndTimeline("):
            eid = a[0] if a else None
            c = open_cut.pop(eid, None)
            if c:
                c["end"] = t
                cutscenes.append(c)
        elif m.startswith("cStoryFsmController.setDialogueSelectedIndex("):
            choices.append((t, a[0] if a else None, a[1] if len(a) > 1 else None, a[3] if len(a) > 3 else None))
        elif m.startswith("MissionManager.setPartySyncInfo("):
            sync_info.append((t, "setPartySyncInfo(mission,stage,on)", None, a))
        elif m.startswith("cMissionHaltController.halt"):
            halts.append((t, m.split("(")[0].split(".")[-1], a))
    if active is not None:
        missions.append({"id": active[0], "start": active[1], "end": None, "quest": False})

    out = [f"# Spans for {ns.trace.name}", "", "## Main missions", "",
           "| Mission | Active from (s) | Cleared at (s) | Duration (s) | Has hunting quest |", "|---|---|---|---|---|"]
    for mi in missions:
        dur = f"{mi['end'] - mi['start']:.0f}" if mi["end"] is not None else "—"
        end = f"{mi['end']:.1f}" if mi["end"] is not None else "(not cleared)"
        out.append(f"| {mname(mi['id'])} | {mi['start']:.1f} | {end} | {dur} | {'yes' if mi['quest'] else ''} |")
    out += ["", "## Hunting quests (gate = accept)", "",
            "| Mission | Accept / gate (s) | Quest session created | Engage monster (s) | Hunt objective cleared (s) | Objective |",
            "|---|---|---|---|---|---|"]
    for q in quests:
        fmt = lambda v: f"{v:.1f}" if isinstance(v, (int, float)) else "—"
        out.append(f"| {mname(q['mission'])} | {fmt(q.get('accept'))} | {'yes' if q.get('session') else 'no'} | "
                   f"{fmt(q.get('engage'))} | {fmt(q.get('end'))} | {q.get('objective', '—')} |")
    out += ["", "## Cutscenes (DemoMediator timeline events)", "",
            "| Event | Mission | Start (s) | Duration (s) | Skipped |", "|---|---|---|---|---|"]
    for c in cutscenes:
        name = tnames.get(c["id"], f"#{c['id']}")
        out.append(f"| {name} ({c['id']}) | {mname(c['mission']) if c['mission'] is not None else '—'} | "
                   f"{c['start']:.1f} | {c['end'] - c['start']:.1f} | {'yes' if c['skips'] else 'no'} |")
    out += ["", "## Dialogue choices", ""]
    out += [f"- t={t:.1f}: dialogue {d} in mission {mname(mi)} → option {idx}" for t, d, mi, idx in choices] or ["- none"]
    out += ["", "## Environment Link / drawing / progress changes", ""]
    out += [f"- t={t:.1f}: {key}: {old} → {new}" for t, key, old, new in sync_info] or ["- none"]
    out += ["", "## Halt (stay-close) events", ""]
    out += [f"- t={t:.1f}: {name} {args}" for t, name, args in halts] or ["- none"]
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
