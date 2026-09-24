#!/usr/bin/env python3
"""Aggiunge una versione di LogLoop alla sorgente apps.json (formato AltStore).

Uso: scripts/update_source.py <versione> <build> <downloadURL> <percorso ipa>
"""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "apps.json"


def bundle_id() -> str:
    """Il bundle ID, letto da project.yml: l'unico posto in cui è definito."""
    match = re.search(r"PRODUCT_BUNDLE_IDENTIFIER:\s*([^\s#]+)", (ROOT / "project.yml").read_text())
    return match.group(1)


def main() -> None:
    version, build, download_url, ipa_path = sys.argv[1:5]
    source = json.loads(SOURCE.read_text())
    app = source["apps"][0]

    # Riallinea gli identificativi della sorgente al bundle ID di project.yml.
    app_id = bundle_id()
    source["identifier"] = f"{app_id}.source"
    source["featuredApps"] = [app_id]
    app["bundleIdentifier"] = app_id

    entry = {
        "version": version,
        "buildVersion": build,
        "date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "localizedDescription": f"LogLoop {version}",
        "downloadURL": download_url,
        "size": os.path.getsize(ipa_path),
        "minOSVersion": "17.0",
        "maxOSVersion": "99.0",
    }
    app["versions"] = [entry] + [v for v in app.get("versions", []) if v["version"] != version]

    # Campi del formato AltStore v1, letti ancora da molti signer (ESign, KravaSign...).
    app["version"] = version
    app["versionDate"] = entry["date"]
    app["versionDescription"] = entry["localizedDescription"]
    app["downloadURL"] = download_url
    app["size"] = entry["size"]

    SOURCE.write_text(json.dumps(source, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
