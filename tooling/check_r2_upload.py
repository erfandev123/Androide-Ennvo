"""Checks the Cloudflare R2 upload with a real signed request.

It puts a tiny file in the bucket and reads it back from the public domain.
It is the same signature the Dart code builds, so a success here means the
app can upload.

The credentials are read from the environment, so they are never written
down:

    CLOUDFLARE_ACCOUNT_ID=... \\
    CLOUDFLARE_R2_ACCESS_KEY_ID=... \\
    CLOUDFLARE_R2_SECRET_ACCESS_KEY=... \\
    CLOUDFLARE_R2_BUCKET_NAME=... \\
    CLOUDFLARE_R2_PUBLIC_DOMAIN=... \\
    python tooling/check_r2_upload.py

Usage:  python tooling/check_r2_upload.py
"""

from __future__ import annotations

import datetime
import hashlib
import hmac
import os
import urllib.request

ACCOUNT_ID = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "")
ACCESS_KEY_ID = os.environ.get("CLOUDFLARE_R2_ACCESS_KEY_ID", "")
SECRET_ACCESS_KEY = os.environ.get("CLOUDFLARE_R2_SECRET_ACCESS_KEY", "")
BUCKET = os.environ.get("CLOUDFLARE_R2_BUCKET_NAME", "")
PUBLIC_DOMAIN = os.environ.get("CLOUDFLARE_R2_PUBLIC_DOMAIN", "")

KEY = "check/ennvo-upload-check.txt"
BODY = b"ennvo native upload check\n"

# The browser of the phone sends this. Cloudflare turns away the tools it
# does not know, so the check has to look like a phone.
USER_AGENT = (
    "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
)


def sign(key: bytes, message: str) -> bytes:
    return hmac.new(key, message.encode("utf-8"), hashlib.sha256).digest()


def signing_key(date_stamp: str) -> bytes:
    key = sign(("AWS4" + SECRET_ACCESS_KEY).encode("utf-8"), date_stamp)
    key = sign(key, "auto")
    key = sign(key, "s3")
    return sign(key, "aws4_request")


def main() -> None:
    if not ACCOUNT_ID or not ACCESS_KEY_ID or not SECRET_ACCESS_KEY:
        raise SystemExit("the Cloudflare credentials are not in the environment")

    now = datetime.datetime.now(datetime.timezone.utc)
    stamp = now.strftime("%Y%m%dT%H%M%SZ")
    date = stamp[:8]

    host = f"{ACCOUNT_ID}.r2.cloudflarestorage.com"
    path = f"/{BUCKET}/{KEY}"
    payload = hashlib.sha256(BODY).hexdigest()

    headers = {
        "host": host,
        "x-amz-content-sha256": payload,
        "x-amz-date": stamp,
        "content-type": "text/plain",
    }
    signed = sorted(headers)
    canonical_headers = "".join(f"{k}:{headers[k]}\n" for k in signed)
    signed_headers = ";".join(signed)

    canonical_request = "\n".join(
        [
            "PUT",
            path,
            "",
            canonical_headers,
            signed_headers,
            payload,
        ]
    )
    scope = f"{date}/auto/s3/aws4_request"
    string_to_sign = "\n".join(
        [
            "AWS4-HMAC-SHA256",
            stamp,
            scope,
            hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
        ]
    )
    signature = hmac.new(
        signing_key(date),
        string_to_sign.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()

    authorization = (
        f"AWS4-HMAC-SHA256 Credential={ACCESS_KEY_ID}/{scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )

    request = urllib.request.Request(
        f"https://{host}{path}",
        data=BODY,
        method="PUT",
        headers={
            "x-amz-content-sha256": payload,
            "x-amz-date": stamp,
            "content-type": "text/plain",
            "authorization": authorization,
        },
    )

    with urllib.request.urlopen(request) as response:
        print(f"upload: {response.status}")

    public = f"{PUBLIC_DOMAIN}/{KEY}"
    read = urllib.request.Request(public, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(read) as response:
        content = response.read().decode("utf-8")
        print(f"public: {response.status} {content!r}")

    if content.strip() != BODY.decode("utf-8").strip():
        raise SystemExit("the file that came back is not the file that went up")


if __name__ == "__main__":
    main()
