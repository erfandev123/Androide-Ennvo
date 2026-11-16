"""Prints the jobs and their steps of a workflow run."""

from __future__ import annotations

import json
import sys
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
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read().decode())


def dump_log(url: str) -> None:
    """Streams a job log into the console."""
    request = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {TOKEN}", "User-Agent": "ennvo-tooling"},
    )
    try:
        with urllib.request.urlopen(request) as response:
            text = response.read().decode("utf-8", "replace")
    except Exception as error:  # noqa: BLE001
        print(f"  log: {error}")
        return

    lines = text.splitlines()
    print("  log (last 60 lines):")
    for line in lines[-60:]:
        print(f"    {line}")


def main() -> None:
    run_id = sys.argv[1]
    data = get(f"/repos/erfandev123/Androide-Ennvo/actions/runs/{run_id}/jobs")
    for job in data.get("jobs", []):
        print(f"{job['name']}: {job.get('conclusion')} {job.get('html_url')}")
        for step in job.get("steps", []):
            print(f"  {step['name']:<48} {step.get('conclusion')}")
        dump_log(job["url"] + "/logs")


if __name__ == "__main__":
    main()
