"""Checks the real reels in the Firebase project through the REST API.

Usage:  python tooling/check_firestore_reels.py
"""

from __future__ import annotations

import json
import urllib.request

PROJECT = "ennvo-6c01c"
KEY = "AIzaSyBF6QrSEtyz61W3_02mQ2K3-1133tWSR8M"
URL = (
    f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents:runQuery?key={KEY}"
)

query = {
    "structuredQuery": {
        "from": [{"collectionId": "posts"}],
        "where": {
            "fieldFilter": {
                "field": {"fieldPath": "type"},
                "op": "EQUAL",
                "value": {"stringValue": "reel"},
            }
        },
        "limit": 10,
    }
}

request = urllib.request.Request(
    URL,
    data=json.dumps(query).encode("utf-8"),
    headers={"Content-Type": "application/json", "User-Agent": "ennvo-tooling"},
    method="POST",
)
with urllib.request.urlopen(request) as response:
    rows = json.loads(response.read().decode())

found = 0
for row in rows:
    doc = row.get("document")
    if not doc:
        continue
    fields = doc.get("fields", {})
    media = fields.get("media", {}).get("arrayValue", {}).get("values", [])
    url = ""
    if media:
        url = media[0].get("stringValue", "")
    print(
        f"{doc['name'].split('/')[-1][:24]:<26} "
        f"type={fields.get('type', {}).get('stringValue', '')} "
        f"media={len(media)} {url[:90]}"
    )
    found += 1

print(f"real reels found: {found}")
