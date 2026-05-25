from __future__ import annotations

import json
from pathlib import Path
from typing import Any


MANIFEST_PATH = Path("data/models/pokemon/generated/manifests/pokemon_import_manifest.json")
REPORT_JSON_PATH = Path("data/models/pokemon/import_reports/pokemon_import_report.json")


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")


def render_text_report(payload: dict[str, Any]) -> str:
    species = payload.get("species", [])
    status_counts: dict[str, int] = {}
    for entry in species:
        status = str(entry.get("status", "unknown"))
        status_counts[status] = status_counts.get(status, 0) + 1

    lines = [
        "Pokemon Batch Import Preflight",
        "==============================",
        f"Generated: {payload.get('generated_at', '')}",
        f"Target species: {len(species)}",
    ]
    excluded = payload.get("target", {}).get("excluded_unreleased", [])
    if excluded:
        lines.append(f"Excluded unreleased: {len(excluded)}")
    for status in sorted(status_counts):
        lines.append(f"{status}: {status_counts[status]}")
    lines.append("")

    if excluded:
        lines.append("Excluded unreleased Pokemon")
        lines.append("---------------------------")
        for entry in excluded:
            lines.append(
                f"- {int(entry.get('dex_number', 0)):04d} "
                f"{entry.get('slug', '?')} "
                f"({entry.get('display_name', '?')}): "
                f"{entry.get('reason', 'pmdo_unreleased')}"
            )
        lines.append("")

    for entry in species:
        line = f"- {entry.get('slug', '?')} ({entry.get('display_name', '?')}) {entry.get('status', '?')}"
        disabled_reason = entry.get("disabled_reason", "")
        if disabled_reason:
            line += f" [{disabled_reason}]"
        lines.append(line)
        substitutions = entry.get("assets", {}).get("sprite_substitutions", {})
        if substitutions:
            for state, reason in sorted(substitutions.items()):
                lines.append(f"    substitution: {state} -> {reason}")
        for warning in entry.get("warnings", []):
            lines.append(f"    warning: {warning}")
    return "\n".join(lines) + "\n"
