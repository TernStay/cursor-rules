#!/usr/bin/env python3
"""Run read-only SQL against a TurnStay production database via Metabase.

    python query.py --databases
    python query.py <db_id> "select ..."
    python query.py <db_id> --file query.sql

Metabase proxies to the read replicas with a read-only role, so this is the
quickest way to see production data without a bastion or a tunnel.
"""

import asyncio
import json
import os
import sys
from pathlib import Path

import httpx
from dotenv import load_dotenv

# The credentials live with the metabase service, not in the calling repo.
ENV_PATH = Path.home() / "TurnStay/metabase/.env"
load_dotenv(ENV_PATH)

BASE = os.environ.get("METABASE_URL", "https://metabase.prod.turnstay.com").rstrip("/")
USER = os.environ.get("METABASE_USER")
PASSWORD = os.environ.get("METABASE_PASSWORD")

# Anything that could change data. Metabase's role is read-only, so these fail
# anyway — refusing here makes the intent explicit rather than relying on that.
FORBIDDEN = (
    "insert ", "update ", "delete ", "drop ", "truncate ", "alter ",
    "create ", "grant ", "revoke ",
)


async def main() -> int:
    if not USER or not PASSWORD:
        print(f"No credentials. Expected METABASE_USER/PASSWORD in {ENV_PATH}")
        return 1
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    async with httpx.AsyncClient(timeout=120) as client:
        response = await client.post(
            f"{BASE}/api/session", json={"username": USER, "password": PASSWORD}
        )
        response.raise_for_status()
        headers = {"X-Metabase-Session": response.json()["id"]}

        if sys.argv[1] == "--databases":
            response = await client.get(f"{BASE}/api/database", headers=headers)
            response.raise_for_status()
            payload = response.json()
            for db in payload.get("data", payload):
                print(f"  id={db['id']:<4} {db['name']}  ({db.get('engine')})")
            return 0

        database_id = int(sys.argv[1])
        if sys.argv[2] == "--file":
            sql = Path(sys.argv[3]).read_text()
        else:
            sql = sys.argv[2]

        lowered = sql.lower()
        if any(word in lowered for word in FORBIDDEN):
            print("Refusing: this looks like it writes. Metabase access is read-only.")
            return 1

        response = await client.post(
            f"{BASE}/api/dataset",
            headers=headers,
            json={
                "type": "native",
                "database": database_id,
                "native": {"query": sql},
            },
        )
        response.raise_for_status()
        payload = response.json()

        if payload.get("status") == "failed":
            print("QUERY FAILED:", payload.get("error"))
            return 1

        columns = [column["display_name"] for column in payload["data"]["cols"]]
        rows = payload["data"]["rows"]

        if "--json" in sys.argv:
            print(json.dumps([dict(zip(columns, row)) for row in rows], default=str))
            return 0

        print(" | ".join(columns))
        print("-" * 72)
        for row in rows:
            print(" | ".join("" if v is None else str(v) for v in row))
        print(f"({len(rows)} rows)")
        return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
