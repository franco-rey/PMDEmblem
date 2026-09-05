import argparse
import json
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_ROOT = PROJECT_ROOT.parent / "PMDODump"
OUTPUT = PROJECT_ROOT / "data" / "models" / "pokemon" / "generated" / "manifests" / "battle_text.json"
TABLES = {"intrinsics": "Intrinsic.txt", "statuses": "Status.txt", "map_statuses": "MapStatus.txt"}


def parse_table(path: Path) -> dict:
    entries: dict = {}
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "|" not in raw:
            continue
        key, _, rest = raw.partition("|")
        field, _, columns = rest.partition("\t")
        parts = key.split("-")
        if len(parts) < 3:
            continue
        slug = "-".join(parts[1:-1])
        english = ""
        for column in columns.split("\t"):
            if column.strip():
                english = column.strip()
                break
        entry = entries.setdefault(slug, {"name": "", "description": ""})
        if field == "data.Name":
            entry["name"] = english
        elif field == "data.Desc":
            entry["description"] = english
    return {slug: entry for slug, entry in entries.items() if entry["name"] or entry["description"]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=os.environ.get("PMD_EMBLEM_PMDO_ROOT", str(DEFAULT_ROOT)))
    parser.add_argument("--output", default=str(OUTPUT))
    args = parser.parse_args()
    string_dir = Path(args.root) / "DataAsset" / "String"
    if not string_dir.is_dir():
        print("battle_text: missing %s" % string_dir)
        return 1
    payload = {"source": str(string_dir)}
    for key, filename in TABLES.items():
        path = string_dir / filename
        payload[key] = parse_table(path) if path.is_file() else {}
        print("battle_text: %s -> %d entries" % (filename, len(payload[key])))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print("battle_text: wrote %s" % output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
