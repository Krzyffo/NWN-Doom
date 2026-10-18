"""Build the player release zip for NWN-Doom.

  py tools/package.py [--module NAME] [--version X.Y]

Takes the saved module from your NWN modules folder and the art hak, checks
that the module is set up for release, and writes build/dist/<NAME>-<X.Y>.zip:

  modules/<NAME>.mod
  hak/nwn_doom.hak
  README.txt               install steps + docs/module_description.txt
  FREEDOOM-LICENSE.txt     licenses/FREEDOOM-COPYING.txt (required by the BSD licence)
  FREEDOOM-CREDITS.txt     licenses/FREEDOOM-CREDITS.txt (the contributor list it refers to)

The zip mirrors the NWN user folder, so players can unzip it straight into
Documents\\Neverwinter Nights. Nothing is uploaded anywhere.

It also writes build/dist/nwn-doom-kit-<X.Y>.zip, for adding NWN-Doom to
another module (docs/adding_to_a_module.md):

  hak/nwn_doom.hak
  erf/nwn_doom.erf         the compiled scripts, from tools/build.py
  ADDING_TO_A_MODULE.md    docs/adding_to_a_module.md
  FREEDOOM-LICENSE.txt, FREEDOOM-CREDITS.txt

Checks (any failure stops the build):
- the module lists the nwn_doom hak
- OnModuleLoad is doom_modload
- the module has an int variable DOOM_WAVES = 1 (the arena needs its waves)
- every src/doom_*.nss script with a main() is compiled into the module
- the module has a description (warning only)
"""
import argparse
import datetime
import json
import os
import subprocess
import sys
import zipfile

import build_erf

ROOT = build_erf.ROOT
NWN_USER = os.environ.get("NWN_USER", r"G:\nwnData")
GFF_TOOL = os.path.join(ROOT, "tools", "neverwinter", "nwn_gff.exe")
DESCRIPTION = os.path.join(ROOT, "docs", "module_description.txt")
LICENSE = os.path.join(ROOT, "licenses", "FREEDOOM-COPYING.txt")
CREDITS = os.path.join(ROOT, "licenses", "FREEDOOM-CREDITS.txt")
TUTORIAL = os.path.join(ROOT, "docs", "adding_to_a_module.md")
SCRIPTS_ERF = build_erf.OUT
DIST = os.path.join(ROOT, "build", "dist")
HAK_NAME = "nwn_doom"
RES_IFO = 2014
RES_NCS = build_erf.RES_TYPES["ncs"]

README_HEAD = """{name} {version}
{line}

Neverwinter Nights: Enhanced Edition module. Doom-style first-person
shooting, built on NWScript.

INSTALL
-------
1. Find your NWN user folder. It is normally
   Documents\\Neverwinter Nights (Steam, GOG and Beamdog versions alike).
2. Unzip this archive into that folder, so that
     {mod_file}   ends up in   Neverwinter Nights\\modules\\
     {hak_file}   ends up in   Neverwinter Nights\\hak\\
3. Start Neverwinter Nights, choose New > Module, pick "{name}" and
   play with any level 1-5 character.

Requires NWN: Enhanced Edition. It does not run on the original 2002 game.

The HUD and weapon art comes from Freedoom (https://freedoom.github.io/),
used under its BSD licence; see FREEDOOM-LICENSE.txt and
FREEDOOM-CREDITS.txt.

"""


def fail(msg):
    sys.exit(f"package: {msg}")


def read_ifo(entries):
    """module.ifo of the module as nwn_gff's JSON."""
    ifo = next((data for resref, rtype, data in entries if resref == "module" and rtype == RES_IFO), None)
    if ifo is None:
        fail("module.ifo not found in the module")
    if not os.path.exists(GFF_TOOL):
        fail(f"{GFF_TOOL} not found; it comes with the neverwinter.nim tools (see README)")
    tmp = os.path.join(ROOT, "build", "package_module.ifo")
    os.makedirs(os.path.dirname(tmp), exist_ok=True)
    with open(tmp, "wb") as f:
        f.write(ifo)
    try:
        out = subprocess.run([GFF_TOOL, "-i", tmp, "-k", "json"], capture_output=True, check=True)
    finally:
        os.remove(tmp)
    return json.loads(out.stdout)


def gff_value(ifo, key, default=None):
    return ifo.get(key, {}).get("value", default)


def check_module(mod_path):
    entries = build_erf.read_erf(mod_path)
    ifo = read_ifo(entries)
    errors = []

    haks = [h.get("Mod_Hak", {}).get("value", "").lower() for h in gff_value(ifo, "Mod_HakList", [])]
    old_hak = (gff_value(ifo, "Mod_Hak") or "").lower()
    if old_hak:
        haks.append(old_hak)
    if HAK_NAME not in haks:
        errors.append(f"the module does not use the {HAK_NAME} hak (Module Properties > Custom Content)")

    on_load = (gff_value(ifo, "Mod_OnModLoad") or "").lower()
    if on_load != "doom_modload":
        errors.append(f"OnModuleLoad is '{on_load}', not doom_modload (Module Properties > Events)")

    # The arena relies on the waves, which only run where DOOM_WAVES = 1.
    waves = [v for v in gff_value(ifo, "VarTable", [])
             if v.get("Name", {}).get("value") == "DOOM_WAVES"
             and v.get("Value", {}).get("value") == 1]
    if not waves:
        errors.append("the module has no int variable DOOM_WAVES = 1, so no waves spawn "
                      "(Module Properties > Advanced > Variables)")

    compiled = {resref for resref, rtype, _ in entries if rtype == RES_NCS}
    for name in sorted(os.listdir(build_erf.SRC)):
        if not (name.startswith("doom_") and name.endswith(".nss")):
            continue
        with open(os.path.join(build_erf.SRC, name), encoding="utf-8") as f:
            if "void main()" not in f.read():
                continue  # include file
        resref = name[:-4]
        if resref not in compiled:
            errors.append(f"{resref} is not compiled into the module (import build/nwn_doom.erf, then Build Module)")

    if errors:
        fail("module is not ready:\n  - " + "\n  - ".join(errors))

    description = gff_value(ifo, "Mod_Description", {})
    if not any(isinstance(v, str) and v.strip() for v in description.values()):
        print("warning: the module has no description; paste docs/module_description.txt "
              "into Module Properties > Description")
    title = gff_value(ifo, "Mod_Name", {}).get("0", "")
    return title


def find_hak():
    for path in (os.path.join(NWN_USER, "hak", HAK_NAME + ".hak"),
                 os.path.join(ROOT, "build", HAK_NAME + ".hak")):
        if os.path.exists(path):
            return path
    fail(f"{HAK_NAME}.hak not found; run tools/wad_to_hak.py first")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--module", default="NWN-Doom",
                        help="module file name in your NWN modules folder, without .mod (default: NWN-Doom)")
    parser.add_argument("--version", default=datetime.date.today().strftime("%Y.%m.%d"),
                        help="version for the zip name and README (default: today's date)")
    args = parser.parse_args()

    mod_path = os.path.join(NWN_USER, "modules", args.module + ".mod")
    if not os.path.exists(mod_path):
        available = sorted(f[:-4] for f in os.listdir(os.path.join(NWN_USER, "modules")) if f.endswith(".mod"))
        fail(f"{mod_path} not found. Modules there: {', '.join(available) or 'none'}. Use --module NAME.")
    for path in (DESCRIPTION, LICENSE, CREDITS, TUTORIAL, SCRIPTS_ERF):
        if not os.path.exists(path):
            fail(f"{path} is missing")

    title = check_module(mod_path)
    hak_path = find_hak()

    with open(DESCRIPTION, encoding="utf-8") as f:
        description = f.read()
    heading = f"{args.module} {args.version}"
    width = max(len(args.module + ".mod"), len(HAK_NAME + ".hak"))
    readme = README_HEAD.format(name=args.module, version=args.version, line="=" * len(heading),
                                mod_file=(args.module + ".mod").ljust(width),
                                hak_file=(HAK_NAME + ".hak").ljust(width)) + description

    os.makedirs(DIST, exist_ok=True)
    zip_path = os.path.join(DIST, f"{args.module}-{args.version}.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(mod_path, f"modules/{args.module}.mod")
        z.write(hak_path, f"hak/{HAK_NAME}.hak")
        # Windows line endings: players open these in Notepad.
        z.writestr("README.txt", readme.replace("\r\n", "\n").replace("\n", "\r\n"))
        z.write(LICENSE, "FREEDOOM-LICENSE.txt")
        z.write(CREDITS, "FREEDOOM-CREDITS.txt")

    print(f"module:  {mod_path}" + (f" (\"{title}\")" if title else ""))
    print(f"hak:     {hak_path}")
    print(f"wrote {zip_path} ({os.path.getsize(zip_path) / 1e6:.1f} MB)")

    kit_path = os.path.join(DIST, f"nwn-doom-kit-{args.version}.zip")
    with zipfile.ZipFile(kit_path, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(hak_path, f"hak/{HAK_NAME}.hak")
        z.write(SCRIPTS_ERF, f"erf/{HAK_NAME}.erf")
        z.write(TUTORIAL, "ADDING_TO_A_MODULE.md")
        z.write(LICENSE, "FREEDOOM-LICENSE.txt")
        z.write(CREDITS, "FREEDOOM-CREDITS.txt")
    print(f"wrote {kit_path} ({os.path.getsize(kit_path) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
