"""Compile src/*.nss with Beamdog's nwn_script_comp and pack the ERF.

  py tools/build.py

Compiled .ncs files go to build/ncs/ and are packed into
build/nwn_doom.erf next to the sources, so an imported module can run
even before the toolset rebuilds it.

The game is found as described in tools/nwn_paths.py (NWN_ROOT, else Steam).
The compiler comes from the neverwinter.nim release, unzipped into
tools/neverwinter/ (https://github.com/niv/neverwinter.nim/releases).
"""
import os
import shutil
import subprocess
import sys
import tempfile

import build_erf
import nwn_paths

ROOT = build_erf.ROOT
COMPILER = os.path.join(ROOT, "tools", "neverwinter", "nwn_script_comp.exe")


def main():
    if not os.path.exists(COMPILER):
        sys.exit(f"compiler not found: {COMPILER}")
    # Start clean, so a deleted script's old .ncs is not packed into the ERF.
    shutil.rmtree(build_erf.NCS, ignore_errors=True)
    os.makedirs(build_erf.NCS)
    # The compiler also wants an NWN user folder; the scripts need nothing
    # from it, so an empty one will do.
    with tempfile.TemporaryDirectory() as user:
        result = subprocess.run([
            COMPILER, "--root", nwn_paths.nwn_root(), "--userdirectory", user,
            "--no-require-entry-point", "-y", "-d", build_erf.NCS, "-c", build_erf.SRC,
        ])
    if result.returncode != 0:
        sys.exit("compile failed")
    build_erf.build(build_erf.OUT)


if __name__ == "__main__":
    main()
