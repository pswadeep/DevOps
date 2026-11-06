#!/usr/bin/env python3
"""Prune old prerelease package versions from an Azure Artifacts feed (keeps anything in the Release view)."""
import argparse, base64, json, os, urllib.request, datetime as dt

ap = argparse.ArgumentParser()
ap.add_argument("--org", required=True); ap.add_argument("--project", required=True); ap.add_argument("--feed", required=True)
ap.add_argument("--keep", type=int, default=20); ap.add_argument("--older-than-days", type=int, default=60)
ap.add_argument("--dry-run", action="store_true")
a = ap.parse_args()

tok = base64.b64encode((":" + os.environ["SYSTEM_ACCESSTOKEN"]).encode()).decode()
H = {"Authorization": "Basic " + tok, "Content-Type": "application/json"}
base = f"https://feeds.dev.azure.com/{a.org}/{a.project}/_apis/packaging/feeds/{a.feed}"

def call(url, method="GET"):
    r = urllib.request.urlopen(urllib.request.Request(url, headers=H, method=method))
    body = r.read()
    return json.loads(body) if body else {}

cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=a.older_than_days)
pkgs = call(f"{base}/packages?includeAllVersions=true&api-version=7.1")["value"]
for p in pkgs:
    vers = sorted(p["versions"], key=lambda v: v["publishDate"], reverse=True)
    for v in vers[a.keep:]:
        in_release = any(x.get("name") == "Release" for x in v.get("views", []))
        old = dt.datetime.fromisoformat(v["publishDate"].replace("Z", "+00:00")) < cutoff
        if in_release or not old:
            continue
        print(("would delete " if a.dry_run else "deleting ") + f"{p['name']} {v['version']}")
        if not a.dry_run:
            proto = p["protocolType"].lower()
            kind = {"npm": "npm", "nuget": "nuget", "upack": "upack"}.get(proto)
            if kind:
                pk = f"https://pkgs.dev.azure.com/{a.org}/{a.project}/_apis/packaging/feeds/{a.feed}/{kind}/packages/{p['name']}/versions/{v['version']}?api-version=7.1"
                call(pk, "DELETE")
