"""Re-runs the failed jobs of a workflow run.

Usage:  python tooling/rerun_ci.py <run id>
"""

from __future__ import annotations

import json
import sys
import urllib.request

TOKEN = open(r"D:\dev\gh_token.txt", encoding="utf-8").read().strip()

run_id = sys.argv[1]
request = urllib.request.Request(
    f"https://api.github.com/repos/erfandev123/Androide-Ennvo/actions/runs/{run_id}/rerun-failed-jobs",
    data=b"{}",
    method="POST",
    headers={
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Authorization": f"Bearer {TOKEN}",
        "User-Agent": "ennvo-tooling",
        "Content-Type": "application/json",
    },
)
with urllib.request.urlopen(request) as response:
    data = json.loads(response.read().decode())
    print("re-run:", response.status, data)
