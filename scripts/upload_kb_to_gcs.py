#!/usr/bin/env python3
"""
One-off script: upload the existing healthflex knowledge base from GitHub repo to GCS.
Run with: ~/.gate/sync-venv/bin/python3 scripts/upload_kb_to_gcs.py

Uploads all .md files from:
  ~/Desktop/looperpowers/skills/healthflex/knowledge/
to:
  gs://looperpowers-kb/squads/healthflex/knowledge/
"""
import sys
import urllib.request
import urllib.parse
from pathlib import Path

SA_FILE = Path("/Applications/Boop.app/Contents/Resources/gcs-service-account.json")
KB_ROOT = Path.home() / "Desktop" / "looperpowers" / "skills" / "healthflex" / "knowledge"
GCS_BUCKET = "looperpowers-kb"
GCS_PREFIX = "squads/healthflex/knowledge"


def get_token(sa_file: Path) -> str:
    from google.oauth2 import service_account
    from google.auth.transport.requests import Request as GoogleRequest
    creds = service_account.Credentials.from_service_account_file(
        str(sa_file),
        scopes=["https://www.googleapis.com/auth/devstorage.read_write"]
    )
    creds.refresh(GoogleRequest())
    return creds.token


def upload(local_path: Path, gcs_object: str, token: str) -> None:
    url = (
        f"https://storage.googleapis.com/upload/storage/v1/b/{GCS_BUCKET}/o"
        f"?uploadType=media&name={urllib.parse.quote(gcs_object, safe='')}"
    )
    req = urllib.request.Request(
        url,
        data=local_path.read_bytes(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "text/markdown; charset=utf-8"},
        method="POST"
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        resp.read()


def main():
    if not SA_FILE.exists():
        print(f"ERROR: service account not found at {SA_FILE}")
        print("Copy gcs-service-account.json to /Applications/Boop.app/Contents/Resources/ first.")
        sys.exit(1)

    if not KB_ROOT.exists():
        print(f"ERROR: knowledge base not found at {KB_ROOT}")
        sys.exit(1)

    files = sorted(KB_ROOT.rglob("*.md"))
    print(f"Found {len(files)} files to upload from {KB_ROOT}")
    print(f"Uploading to gs://{GCS_BUCKET}/{GCS_PREFIX}/\n")

    print("Authenticating with service account...", flush=True)
    token = get_token(SA_FILE)
    print("OK\n")

    uploaded = 0
    failed = 0
    for f in files:
        rel = f.relative_to(KB_ROOT)
        gcs_path = f"{GCS_PREFIX}/{rel}"
        print(f"  {rel}", end="", flush=True)
        try:
            upload(f, gcs_path, token)
            print(" ✓")
            uploaded += 1
        except Exception as e:
            print(f" ✗ {e}")
            failed += 1

    print(f"\n{'='*50}")
    print(f"Done: {uploaded} uploaded, {failed} failed")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
