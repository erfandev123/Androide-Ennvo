"""Puts the Cloudflare R2 credentials into the secrets of the repository.

The values are encrypted with the public key of the repository (a NaCl
sealed box) and sent to the GitHub API. They never appear in the source and
never appear in a log.

The credentials are read from the environment, so they are never written
down:

    CLOUDFLARE_ACCOUNT_ID=... \\
    CLOUDFLARE_R2_ACCESS_KEY_ID=... \\
    CLOUDFLARE_R2_SECRET_ACCESS_KEY=... \\
    CLOUDFLARE_R2_BUCKET_NAME=... \\
    CLOUDFLARE_R2_PUBLIC_DOMAIN=... \\
    python tooling/set_r2_secrets.py

Usage:  python tooling/set_r2_secrets.py
"""

from __future__ import annotations

import base64
import json
import os
import urllib.request

from nacl import encoding, public

OWNER = "erfandev123"
REPO = "Androide-Ennvo"
API = "https://api.github.com"

# The name of the secret in the repository and the name of the variable
# that carries the value.
SECRETS = {
    "CLOUDFLARE_ACCOUNT_ID": "CLOUDFLARE_ACCOUNT_ID",
    "CLOUDFLARE_R2_ACCESS_KEY_ID": "CLOUDFLARE_R2_ACCESS_KEY_ID",
    "CLOUDFLARE_R2_SECRET_ACCESS_KEY": "CLOUDFLARE_R2_SECRET_ACCESS_KEY",
    "CLOUDFLARE_R2_BUCKET_NAME": "CLOUDFLARE_R2_BUCKET_NAME",
    "CLOUDFLARE_R2_PUBLIC_DOMAIN": "CLOUDFLARE_R2_PUBLIC_DOMAIN",
}

TOKEN_FILE = r"D:\dev\gh_token.txt"


def token() -> str:
    for candidate in (TOKEN_FILE, os.path.expanduser("~/.gh_token")):
        if os.path.exists(candidate):
            with open(candidate, encoding="utf-8") as handle:
                return handle.read().strip()
    raise SystemExit("no GitHub token found")


def request(method: str, url: str, body: dict | None = None) -> dict:
    data = None
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Authorization": f"Bearer {token()}",
        "User-Agent": "ennvo-tooling",
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req) as response:
        raw = response.read().decode("utf-8")
        return json.loads(raw) if raw else {}


def main() -> None:
    key = request(
        "GET",
        f"{API}/repos/{OWNER}/{REPO}/actions/secrets/public-key",
    )
    public_key = public.PublicKey(key["key"], encoding.Base64Encoder())
    key_id = key["key_id"]

    for name, variable in SECRETS.items():
        value = os.environ.get(variable, "").strip()
        if not value:
            print(f"  skipped {name} - {variable} is not set")
            continue

        sealed = public.SealedBox(public_key).encrypt(value.encode("utf-8"))
        request(
            "PUT",
            f"{API}/repos/{OWNER}/{REPO}/actions/secrets/{name}",
            {
                "encrypted_value": base64.b64encode(sealed).decode("utf-8"),
                "key_id": key_id,
            },
        )
        print(f"  set {name}")

    print("==> the secrets of the repository are set")


if __name__ == "__main__":
    main()
