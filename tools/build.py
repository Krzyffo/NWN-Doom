"""Compile src/*.nss with Beamdog's nwn_script_comp and pack the ERF.

  py tools/build.py

Compiled .ncs files go to build/ncs/ and are packed into
build/nwn_doom.erf next to the sources, so an imported module can run
even before the toolset rebuilds it.

Paths can be overridden with the NWN_ROOT and NWN_USER environment variables.
The compiler comes from the neverwinter.nim release, unzipped into
tools/neverwinter/ (https://github.com/niv/neverwinter.nim/releases).
"""
import os
import subprocess
import sys

import build_erf

ROOT = build_erf.ROOT
COMPILER = os.path.join(ROOT, "tools", "neverwinter", "nwn_script_comp.exe")
NWN_ROOT = os.environ.get("NWN_ROOT", r"G:\SteamLibrary\steamapps\common\Neverwinter Nights")
NWN_USER = os.environ.get("NWN_USER", r"G:\nwnData")  # see [Alias] HD0 in nwn.ini


def main():
    if not os.path.exists(COMPILER):
        sys.exit(f"compiler not found: {COMPILER}")
    os.makedirs(build_erf.NCS, exist_ok=True)
    result = subprocess.run([
        COMPILER, "--root", NWN_ROOT, "--userdirectory", NWN_USER,
        "--no-require-entry-point", "-y", "-d", build_erf.NCS, "-c", build_erf.SRC,
    ])
    if result.returncode != 0:
        sys.exit("compile failed")
    build_erf.build(build_erf.OUT)


if __name__ == "__main__":
    main()
