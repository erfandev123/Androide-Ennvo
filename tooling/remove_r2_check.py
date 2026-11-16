"""Removes the file of the upload check from the bucket.

Usage:  python tooling/remove_r2_check.py
"""

from __future__ import annotations

import datetime
import hashlib
import hmac
import urllib.request

from check_r2_upload import (
    ACCESS_KEY_ID,
    ACCOUNT_ID,
    BUCKET,
    SECRET_ACCESS_KEY,
    signing_key,
)

KEY = "check/ennvo-upload-check.txt"


def main() -> None:
    now = datetime.datetime.now(datetime.timezone.utc)
    stamp = now.strftime("%Y%m%dT%H%M%SZ")
    date = stamp[:8]

    host = f"{ACCOUNT_ID}.r2.cloudflarestorage.com"
    path = f"/{BUCKET}/{KEY}"
    payload = hashlib.sha256(b"").hexdigest()

    headers = {
        "host": host,
        "x-amz-content-sha256": payload,
        "x-amz-date": stamp,
    }
    signed = sorted(headers)
    canonical_headers = "".join(f"{k}:{headers[k]}\n" for k in signed)
    signed_headers = ";".join(signed)

    canonical_request = "\n".join(
        ["DELETE", path, "", canonical_headers, signed_headers, payload]
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
        method="DELETE",
        headers={
            "x-amz-content-sha256": payload,
            "x-amz-date": stamp,
            "authorization": authorization,
        },
    )
    with urllib.request.urlopen(request) as response:
        print(f"delete: {response.status}")


if __name__ == "__main__":
    main()
