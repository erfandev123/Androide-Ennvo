"""Downloads the APK of the last Android build.

The artifact of the run is fetched and unpacked into a folder, so the APK
can be put on a phone.

Usage:  python tooling/download_apk.py [folder]
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
import zipfile

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


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """The redirect of the artifact is followed by hand.

    GitHub sends the file to a pre-signed address that refuses the
    `Authorization` header, so it has to be taken off.
    """

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def download(url: str, target: str) -> None:
    headers = {
        # The artifact endpoint of the API only accepts the JSON media type.
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Authorization": f"Bearer {token()}",
        "User-Agent": "ennvo-tooling",
    }

    opener = urllib.request.build_opener(_NoRedirect)
    request = urllib.request.Request(url, headers=headers)

    try:
        with opener.open(request) as response:
            location = response.geturl()
            data = response.read()
    except urllib.error.HTTPError as error:
        if error.code not in (301, 302, 303, 307, 308):
            raise
        location = error.headers["Location"]

    # The pre-signed address does not want the token.
    plain = urllib.request.Request(
        location, headers={"User-Agent": "ennvo-tooling"}
    )
    with urllib.request.urlopen(plain) as response:
        with open(target, "wb") as handle:
            while True:
                chunk = response.read(1024 * 256)
                if not chunk:
                    break
                handle.write(chunk)


def main() -> None:
    folder = sys.argv[1] if len(sys.argv) > 1 else "ennvo-apk"
    os.makedirs(folder, exist_ok=True)

    runs = get(f"/repos/{OWNER}/{REPO}/actions/runs?per_page=20")
    target = None
    for run in runs.get("workflow_runs", []):
        if run["name"] != "Android APK":
            continue
        if run["status"] != "completed" or run.get("conclusion") != "success":
            continue
        target = run
        break

    if target is None:
        raise SystemExit("no successful Android build found")

    print(f"run: {target['id']} {target['html_url']}")

    artifacts = get(f"/repos/{OWNER}/{REPO}/actions/runs/{target['id']}/artifacts")
    items = artifacts.get("artifacts", [])
    if not items:
        raise SystemExit("the build has no artifact")

    for item in items:
        name = item["name"]
        print(f"artifact: {name} ({item['size_in_bytes']} bytes)")

        archive = os.path.join(folder, f"{name}.zip")
        download(item["archive_download_url"], archive)

        with zipfile.ZipFile(archive) as zipped:
            zipped.extractall(folder)
        os.remove(archive)

    for name in sorted(os.listdir(folder)):
        path = os.path.join(folder, name)
        if os.path.isfile(path):
            size = os.path.getsize(path) / (1024 * 1024)
            print(f"  {name}  {size:.2f} MB")


if __name__ == "__main__":
    main()
