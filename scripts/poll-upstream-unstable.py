#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import urllib.request
from pathlib import Path
from urllib.parse import urlencode


ROOT = Path(__file__).resolve().parents[1]
SOURCE_FILE = ROOT / "pkgs" / "gsd-2" / "source-unstable.json"
UPSTREAM_COMMITS_URL = "https://api.github.com/repos/gsd-build/gsd-2/commits"
DISPATCH_URL_TEMPLATE = "https://api.github.com/repos/{repo}/dispatches"
PULLS_URL_TEMPLATE = "https://api.github.com/repos/{repo}/pulls"
DISPATCH_EVENT_TYPE = "upstream-unstable-update"


def fetch_latest_commit() -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "gsd-2-nix-release-bot",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    query = urlencode({"sha": "main", "per_page": 1})
    request = urllib.request.Request(f"{UPSTREAM_COMMITS_URL}?{query}", headers=headers)
    with urllib.request.urlopen(request) as response:
        payload = json.load(response)

    if not payload:
        raise RuntimeError("upstream main commits payload was empty")

    commit = payload[0]
    sha = commit.get("sha")
    if not sha:
        raise RuntimeError("upstream latest commit payload did not include sha")

    return {
        "sha": sha,
        "short_sha": sha[:7],
        "html_url": commit.get("html_url", ""),
        "commit_date": commit.get("commit", {}).get("committer", {}).get("date", ""),
    }


def dispatch_update(payload: dict[str, str]) -> None:
    repo = os.environ.get("GITHUB_REPOSITORY")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not repo:
        raise RuntimeError("GITHUB_REPOSITORY is not set")
    if not token:
        raise RuntimeError("GITHUB_TOKEN is not set")

    request = urllib.request.Request(
        DISPATCH_URL_TEMPLATE.format(repo=repo),
        data=json.dumps(
            {
                "event_type": DISPATCH_EVENT_TYPE,
                "client_payload": payload,
            }
        ).encode("utf-8"),
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "gsd-2-nix-release-bot",
        },
        method="POST",
    )
    with urllib.request.urlopen(request):
        pass


def has_open_release_pr(target_sha: str) -> bool:
    repo = os.environ.get("GITHUB_REPOSITORY")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not repo:
        raise RuntimeError("GITHUB_REPOSITORY is not set")
    if not token:
        raise RuntimeError("GITHUB_TOKEN is not set")

    owner, _ = repo.split("/", 1)
    branch = f"bot/upstream-gsd-2-unstable-{target_sha[:7]}"
    query = urlencode(
        {
            "state": "open",
            "head": f"{owner}:{branch}",
        }
    )
    request = urllib.request.Request(
        f"{PULLS_URL_TEMPLATE.format(repo=repo)}?{query}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "gsd-2-nix-release-bot",
        },
    )
    with urllib.request.urlopen(request) as response:
        payload = json.load(response)
    return bool(payload)


def main() -> int:
    current_info = json.loads(SOURCE_FILE.read_text(encoding="utf-8"))
    current_rev = current_info.get("rev")
    if not current_rev:
        raise RuntimeError("could not find rev assignment in source-unstable.json")

    commit = fetch_latest_commit()
    target_sha = commit["sha"]

    if current_rev == target_sha:
        print(
            json.dumps(
                {
                    "updated": False,
                    "current_rev": current_rev,
                    "target_rev": target_sha,
                }
            )
        )
        return 0

    if has_open_release_pr(target_sha):
        print(
            json.dumps(
                {
                    "updated": False,
                    "reason": "open-pr-exists",
                    "current_rev": current_rev,
                    "target_rev": target_sha,
                    "commit_url": commit["html_url"],
                }
            )
        )
        return 0

    dispatch_update(
        {
            "current_rev": current_rev,
            "target_rev": target_sha,
            "short_sha": commit["short_sha"],
            "commit_url": commit["html_url"],
            "commit_date": commit["commit_date"],
        }
    )
    print(
        json.dumps(
            {
                "updated": True,
                "current_rev": current_rev,
                "target_rev": target_sha,
                "short_sha": commit["short_sha"],
                "commit_url": commit["html_url"],
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
