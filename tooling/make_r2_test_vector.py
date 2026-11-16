"""Writes the test vector of the Cloudflare signature.

The Dart code signs the uploads with the same algorithm, and the test of
the app compares its signature with this one. If the two ever drift, the
test fails.

The vector uses a fixed key and a fixed secret - not the real ones - so
nothing secret is written down.

Usage:  python tooling/make_r2_test_vector.py
"""

from __future__ import annotations

import datetime
import hashlib
import hmac
import json

ACCOUNT_ID = "f45c8ffc24470718062d4b2eab12c2cd"
ACCESS_KEY_ID = "AKIATESTVECTOR00000"
SECRET_ACCESS_KEY = "test-vector-secret-key-0000000000000000000"
BUCKET = "ennvo-storage"

KEY = "reels/test-vector.mp4"
BODY = b"ennvo signature test vector"
CONTENT_TYPE = "video/mp4"
STAMP = "20240102T030405Z"


def sign(key: bytes, message: str) -> bytes:
    return hmac.new(key, message.encode("utf-8"), hashlib.sha256).digest()


def signing_key(date_stamp: str) -> bytes:
    key = sign(("AWS4" + SECRET_ACCESS_KEY).encode("utf-8"), date_stamp)
    key = sign(key, "auto")
    key = sign(key, "s3")
    return sign(key, "aws4_request")


def main() -> None:
    date = STAMP[:8]
    host = f"{ACCOUNT_ID}.r2.cloudflarestorage.com"
    path = f"/{BUCKET}/{KEY}"
    payload = hashlib.sha256(BODY).hexdigest()

    headers = {
        "host": host,
        "x-amz-content-sha256": payload,
        "x-amz-date": STAMP,
        "content-type": CONTENT_TYPE,
    }
    signed = sorted(headers)
    canonical_headers = "".join(f"{k}:{headers[k]}\n" for k in signed)
    signed_headers = ";".join(signed)

    canonical_request = "\n".join(
        ["PUT", path, "", canonical_headers, signed_headers, payload]
    )
    scope = f"{date}/auto/s3/aws4_request"
    string_to_sign = "\n".join(
        [
            "AWS4-HMAC-SHA256",
            STAMP,
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

    print(
        json.dumps(
            {
                "key": KEY,
                "contentType": CONTENT_TYPE,
                "body": BODY.decode("utf-8"),
                "timestamp": STAMP,
                "accessKey": ACCESS_KEY_ID,
                "secretKey": SECRET_ACCESS_KEY,
                "authorization": authorization,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
