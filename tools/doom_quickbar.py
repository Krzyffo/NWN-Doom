"""Put the NWN-Doom weapon keys on a character's quickbar.

  py tools/doom_quickbar.py CHARACTER [--dry-run]

CHARACTER is a .bic in your NWN localvault (name without .bic), or a path
to any .bic file. F1-F3 become text macros that send /1, /2 and /3, which
doom_chat turns into fist, pistol and shotgun: an instant switch, unlike the
"1: Fist" style items, which take NWN's 1 s item activation.

No script can change a quickbar in game (NWN:EE has no function for it), so
this edits the character file before you play. The original is kept next to
it as CHARACTER.bic.bak-<timestamp>; the game ignores those files.

Single-player games store the quickbar in the save, not in the character
file, so a character keeps these keys for every new game started with it.
"""
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys

import nwn_paths

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GFF_TOOL = os.path.join(ROOT, "tools", "neverwinter", "nwn_gff.exe")

QUICKBAR_SLOTS = 36          # F1-F12, Shift+F1-F12, Ctrl+F1-F12
QB_TYPE_EMPTY = 0
QB_TYPE_TEXT_MACRO = 18      # QBCommandLabel + QBCommandLine, sent as chat
MACROS = [                   # (slot, label, chat line); slot 0 is F1
    (0, "Fist", "/1"),
    (1, "Pistol", "/2"),
    (2, "Shotgun", "/3"),
]


def gff_to_json(path):
    out = subprocess.run([GFF_TOOL, "-i", path, "-k", "json"], capture_output=True)
    if out.returncode:
        sys.exit(f"could not read {path}: {out.stderr.decode(errors='replace').strip()}")
    return json.loads(out.stdout)


def json_to_gff(data, path):
    tmp = path + ".tmp.json"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f)
    try:
        out = subprocess.run([GFF_TOOL, "-i", tmp, "-l", "json", "-o", path, "-k", "gff"],
                             capture_output=True)
        if out.returncode:
            sys.exit(f"could not write {path}: {out.stderr.decode(errors='replace').strip()}")
    finally:
        os.remove(tmp)


def describe(slot):
    t = slot.get("QBObjectType", {}).get("value", 0)
    if t == QB_TYPE_EMPTY:
        return "empty"
    if t == QB_TYPE_TEXT_MACRO:
        return f"macro '{slot.get('QBCommandLabel', {}).get('value', '')}'"
    return f"slot type {t}"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("character", help="localvault character name (without .bic) or a .bic path")
    parser.add_argument("--dry-run", action="store_true", help="show what would change, write nothing")
    args = parser.parse_args()

    path = args.character
    if not path.lower().endswith(".bic"):
        path = os.path.join(nwn_paths.nwn_user(), "localvault", path + ".bic")
    if not os.path.exists(path):
        sys.exit(f"{path} not found")
    if not os.path.exists(GFF_TOOL):
        sys.exit(f"{GFF_TOOL} not found; it comes with the neverwinter.nim tools (see docs/building.md)")

    data = gff_to_json(path)
    if data.get("__data_type", "").strip() != "BIC":
        sys.exit(f"{path} is not a character file ({data.get('__data_type')})")

    qb = data.setdefault("QBList", {"type": "list", "value": []})["value"]
    while len(qb) < QUICKBAR_SLOTS:
        qb.append({"__struct_id": 0, "QBObjectType": {"type": "byte", "value": QB_TYPE_EMPTY}})

    for slot, label, line in MACROS:
        print(f"F{slot + 1}: {describe(qb[slot])} -> macro '{label}' sending {line}")
        qb[slot] = {
            "__struct_id": 0,
            "QBCommandLabel": {"type": "cexostring", "value": label},
            "QBCommandLine": {"type": "cexostring", "value": line},
            "QBObjectType": {"type": "byte", "value": QB_TYPE_TEXT_MACRO},
        }

    if args.dry_run:
        print("dry run: nothing written")
        return

    backup = path + ".bak-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    shutil.copy2(path, backup)
    json_to_gff(data, path)

    # Read it back to make sure the game will see the macros.
    check = gff_to_json(path)["QBList"]["value"]
    for slot, label, line in MACROS:
        got = check[slot]
        if (got.get("QBObjectType", {}).get("value") != QB_TYPE_TEXT_MACRO
                or got.get("QBCommandLine", {}).get("value") != line):
            shutil.copy2(backup, path)
            sys.exit(f"verification failed on F{slot + 1}; restored the original from {backup}")
    print(f"updated {path}\nbackup  {backup}")


if __name__ == "__main__":
    main()
