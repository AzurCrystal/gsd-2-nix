#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from upstream_source_metadata import (
    collect_upstream_source_metadata,
    fetch_latest_github_release,
    prefetch_github_source,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE_FILE = ROOT / "pkgs" / "gsd-2" / "source.json"


def emit_outputs(path: Path | None, values: dict[str, str]) -> None:
    if path is None:
        return

    lines = [f"{key}={value}" for key, value in values.items()]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Refresh gsd-2 upstream release metadata."
    )
    parser.add_argument(
        "--output-file",
        type=Path,
        help="Write GitHub Actions outputs to this file",
    )
    args = parser.parse_args()

    release = fetch_latest_github_release("gsd-build", "gsd-2")
    rtk_release = fetch_latest_github_release("rtk-ai", "rtk")
    current_info = json.loads(SOURCE_FILE.read_text(encoding="utf-8"))

    current_version = current_info.get("version")
    if not current_version:
        raise RuntimeError("could not find version assignment in source.json")
    current_rtk_version = current_info.get("rtkVersion", "")

    target_version = release["version"]
    tag_name = release["tag_name"]
    source = prefetch_github_source("gsd-build", "gsd-2", tag_name)
    source_root = Path(source["storePath"])
    target_info = dict(current_info)
    target_info["version"] = target_version
    target_info["srcHash"] = source["hash"]
    target_info.update(collect_upstream_source_metadata(source_root, rtk_release))

    if current_info == target_info:
        emit_outputs(
            args.output_file,
            {
                "updated": "false",
                "current_version": current_version,
                "target_version": target_version,
                "tag_name": tag_name,
                "release_url": release["html_url"],
                "hash": "",
                "current_rtk_version": current_rtk_version,
                "target_rtk_version": rtk_release["version"],
                "rtk_tag_name": rtk_release["tag_name"],
                "rtk_release_url": rtk_release["html_url"],
                "rtk_hash": "",
            },
        )
        print(
            json.dumps(
                {
                    "updated": False,
                    "version": current_version,
                    "tag_name": tag_name,
                    "rtk_version": current_rtk_version,
                    "rtk_tag_name": rtk_release["tag_name"],
                }
            )
        )
        return 0

    SOURCE_FILE.write_text(
        json.dumps(target_info, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    emit_outputs(
        args.output_file,
        {
            "updated": "true",
            "current_version": current_version,
            "target_version": target_version,
            "tag_name": tag_name,
            "release_url": release["html_url"],
            "hash": source["hash"],
            "current_rtk_version": current_rtk_version,
            "target_rtk_version": target_info["rtkVersion"],
            "rtk_tag_name": rtk_release["tag_name"],
            "rtk_release_url": rtk_release["html_url"],
            "rtk_hash": target_info["rtkSrcHash"],
        },
    )
    print(
        json.dumps(
            {
                "updated": True,
                "current_version": current_version,
                "target_version": target_version,
                "tag_name": tag_name,
                "hash": source["hash"],
                "current_rtk_version": current_rtk_version,
                "target_rtk_version": target_info["rtkVersion"],
                "rtk_tag_name": rtk_release["tag_name"],
                "rtk_hash": target_info["rtkSrcHash"],
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
