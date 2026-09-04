import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "logs/debug/move_verification/pilot_moves_report.json"


def main() -> int:
    log_path = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    data = json.loads(REPORT.read_text())
    errors: dict[str, list[str]] = {}
    if log_path and log_path.exists():
        current = ""
        for line in log_path.read_text(errors="replace").splitlines():
            if line.startswith("verify: done"):
                current = ""
                continue
            m = re.search(r"verify: begin (\S+) (\S+)", line)
            if m:
                current = f"{m.group(1)}:{m.group(2)}"
                continue
            if current and ("SCRIPT ERROR" in line or "ERROR:" in line):
                errors.setdefault(current, []).append(line.strip()[:160])
    rows = []
    for r in data["results"]:
        key = f"{r['species']}:{r['move']}"
        errs = errors.get(key, [])
        verdict = r["verdict"] if not errs else f"{r['verdict']}+error"
        rows.append((r["species"][5:], r["move"], verdict, ",".join(r.get("missing", [])), ",".join(r.get("achieved", [])), r.get("defender_hp"), r.get("weather_after_move", ""), len(errs)))
    out = [f"# Pilot move verification ({data['generated']}, windowed={data['windowed']})", "", f"counts: {json.dumps(data['counts'])}", "", "| species | move | verdict | missing | achieved | defender hp | weather | errors |", "|---|---|---|---|---|---|---|---|"]
    for row in rows:
        out.append("| " + " | ".join(str(c) for c in row) + " |")
    md = REPORT.with_suffix(".md")
    md.write_text("\n".join(out) + "\n")
    bad = [row for row in rows if row[2] not in ("ok",)]
    print(f"summary: {len(rows)} moves, {len(bad)} not ok -> {md}")
    for row in bad:
        print("  ", " | ".join(str(c) for c in row[:5]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
