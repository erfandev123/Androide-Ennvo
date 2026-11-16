"""Prints the last workflow runs of the repository.

Usage:  python tooling/show_runs.py
"""

from __future__ import annotations

import json
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
    runs = get(f"/repos/{OWNER}/{REPO}/actions/runs?per_page=8")
    for run in runs.get("workflow_runs", []):
        print(
            f"{run['name']:<14} {run['head_sha'][:8]} "
            f"{run['status']:<12} {str(run.get('conclusion')):<10} "
            f"{run['id']}  {run['created_at']}"
        )


if __name__ == "__main__":
    main()
