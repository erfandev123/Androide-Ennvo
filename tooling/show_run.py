"""Prints the raw details of a workflow run."""

from __future__ import annotations

import json
import sys
import urllib.request

TOKEN = open(r"D:\dev\gh_token.txt", encoding="utf-8").read().strip()

req = urllib.request.Request(
    f"https://api.github.com/repos/erfandev123/Androide-Ennvo/actions/runs/{sys.argv[1]}",
    headers={
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Authorization": f"Bearer {TOKEN}",
        "User-Agent": "ennvo-tooling",
    },
)
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read().decode())

for key in (
    "id",
    "name",
    "status",
    "conclusion",
    "created_at",
    "updated_at",
    "run_started_at",
    "run_attempt",
    "event",
    "head_sha",
    " html_url",
):
    print(f"{key}: {data.get(key)}")

print("triggering_actor:", data.get("triggering_actor", {}).get("login"))
