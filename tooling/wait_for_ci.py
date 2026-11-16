"""Waits until the workflows of a commit are done.

Usage:  python tooling/wait_for_ci.py <sha>
"""

from __future__ import annotations

import json
import sys
import time
import urllib.request

TOKEN = open(r"D:\dev\gh_token.txt", encoding="utf-8").read().strip()


def get(path: str) -> dict:
    request = urllib.request.Request(
        f"https://api.github.com{path}",
        headers={
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Authorization": f"Bearer {TOKEN}",
            "User-Agent": "ennvo-tooling",
        },
    )
    # The API sometimes closes a big response early. A retry is enough.
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.loads(response.read().decode())
        except Exception:  # noqa: BLE001
            if attempt == 4:
                raise
            time.sleep(3)
    return {}


def main() -> None:
    sha = sys.argv[1]
    deadline = time.time() + 45 * 60
    reported: dict[str, str] = {}

    while time.time() < deadline:
        runs = get(
            "/repos/erfandev123/Androide-Ennvo/actions/runs?per_page=30"
        ).get("workflow_runs", [])
        mine = [r for r in runs if r["head_sha"].startswith(sha)]

        if len(mine) == 3 and all(r["status"] == "completed" for r in mine):
            for run in mine:
                print(
                    f"{run['name']:<14} {run.get('conclusion')}  {run['id']}",
                    flush=True,
                )
            return

        for run in mine:
            label = (
                f"{run['name']:<14} {run['status']} "
                f"{run.get('conclusion') or ''}"
            )
            if reported.get(run["name"]) != label:
                reported[run["name"]] = label
                print(label, flush=True)

        time.sleep(20)

    print("==> timeout", flush=True)


if __name__ == "__main__":
    main()
