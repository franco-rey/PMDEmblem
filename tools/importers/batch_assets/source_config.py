from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[3]
LOCAL_CONFIG_PATH = PROJECT_ROOT / "tools" / "importers" / "local_sources.json"


DEFAULTS = {
    "pmdo_root": "/Users/franco/Documents/GitHub/PMDODump",
    "raw_asset_root": "/Users/franco/Documents/GitHub/RawAsset",
    "sprite_collab_root": "/Users/franco/Documents/GitHub/SpriteCollab",
}


ENV_KEYS = {
    "pmdo_root": "PMD_EMBLEM_PMDO_ROOT",
    "raw_asset_root": "PMD_EMBLEM_RAW_ASSET_ROOT",
    "sprite_collab_root": "PMD_EMBLEM_SPRITE_COLLAB_ROOT",
}


@dataclass(frozen=True)
class SourceConfig:
    pmdo_root: Path
    raw_asset_root: Path
    sprite_collab_root: Path | None

    @property
    def monster_dir(self) -> Path:
        return self.pmdo_root / "DumpAsset" / "Data" / "Monster"

    @property
    def skill_dir(self) -> Path:
        return self.pmdo_root / "DumpAsset" / "Data" / "Skill"

    @property
    def universal_path(self) -> Path:
        return self.pmdo_root / "DumpAsset" / "Data" / "Universal.json"

    @property
    def raw_sprite_dir(self) -> Path:
        return self.raw_asset_root / "Sprite"

    @property
    def raw_portrait_dir(self) -> Path:
        return self.raw_asset_root / "Portrait"

    @property
    def sprite_collab_sprite_dir(self) -> Path | None:
        return self.sprite_collab_root / "sprite" if self.sprite_collab_root is not None else None

    @property
    def sprite_collab_portrait_dir(self) -> Path | None:
        return self.sprite_collab_root / "portrait" if self.sprite_collab_root is not None else None

    def to_manifest(self) -> dict[str, str]:
        out = {
            "pmdo_root": str(self.pmdo_root),
            "raw_asset_root": str(self.raw_asset_root),
        }
        if self.sprite_collab_root is not None:
            out["sprite_collab_root"] = str(self.sprite_collab_root)
        return out


def load_config(args: Any) -> SourceConfig:
    local = _load_local_config()
    values: dict[str, str | None] = {}
    for key, default_value in DEFAULTS.items():
        cli_value = getattr(args, key, None)
        env_value = os.environ.get(ENV_KEYS[key], "")
        local_value = str(local.get(key, "")).strip()
        values[key] = str(cli_value or env_value or local_value or default_value).strip()

    sprite_collab_root = Path(values["sprite_collab_root"]).expanduser()
    return SourceConfig(
        pmdo_root=Path(values["pmdo_root"]).expanduser(),
        raw_asset_root=Path(values["raw_asset_root"]).expanduser(),
        sprite_collab_root=sprite_collab_root if str(sprite_collab_root) else None,
    )


def _load_local_config() -> dict[str, Any]:
    if not LOCAL_CONFIG_PATH.exists():
        return {}
    try:
        with LOCAL_CONFIG_PATH.open("r", encoding="utf-8") as handle:
            loaded = json.load(handle)
        return loaded if isinstance(loaded, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}
