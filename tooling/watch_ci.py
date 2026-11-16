"""Watches the workflows of the repository.

Usage:  python tooling/watch_ci.py [minutes]
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request

OWNER = "erfandev123"
REPO = "Androide-Ennvo"
API = "https://api.github.com"
TOKEN_FILE = r"D:\dev\gh_token.txt"


def token() -> str:
    with open(TOKEN_FILE, encoding="utf-8") as handle:
        return handle.read().strip()


def get(path: str) -> dict:
    request = urllib.request.Request(
        f"{API}{path}",
        headers={
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Authorization": f"Bearer {token()}",
            "User-Agent": "ennvo-tooling",
        },
    )
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> None:
    minutes = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    deadline = time.time() + minutes * 60
    seen: dict[str, str] = {}

    while time.time() < deadline:
        runs = get(f"/repos/{OWNER}/{REPO}/actions/runs?per_page=8")
        for run in runs.get("workflow_runs", []):
            key = f"{run['id']}"
            status = run["status"]
            conclusion = run.get("conclusion") or ""
            label = f"{run['name']:<14} {run['head_branch']:<8} {status:<10} {conclusion}"
            if seen.get(key) != label:
                seen[key] = label
                print(label, flush=True)

            if status == "completed":
                jobs = get(f"/repos/{OWNER}/{REPO}/actions/runs/{key}/jobs")
                for job in jobs.get("jobs", []):
                    state = f"      - {job['name']}: {job.get('conclusion')}"
                    if seen.get(f"{key}-{job['id']}") != state:
                        seen[f"{key}-{job['id']}"] = state
                        print(state, flush=True)

        # Everything of the newest run is done?
        newest = runs.get("workflow_runs", [])
        if newest:
            first = newest[0]
            if first["status"] == "completed" and first.get("created_at") == max(
                r["created_at"] for r in newest
            ):
                jobs = get(f"/repos/{OWNER}/{REPO}/actions/runs/{first['id']}/jobs")
                if all(job.get("conclusion") for job in jobs.get("jobs", [])):
                    print("==> everything of the newest run is done", flush=True)
                    return

        time.sleep(20)

    print("==> the time is over")


if __name__ == "__main__":
    main()
