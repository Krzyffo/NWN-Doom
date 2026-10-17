"""Pack the NWScript sources into an .erf the NWN toolset can import.

  py tools/build_erf.py            -> build/nwn_doom.erf
  py tools/build_erf.py --list F   -> print the contents of an existing .erf/.hak

In the toolset: File > Import..., pick the .erf, then Build > Build Module
(or Compile all scripts) so the .nss files get compiled to .ncs.

write_erf() is also used by wad_to_hak.py to write the art hak; the output
matches what Beamdog's nwn_erf produces for the same files.
"""
import datetime
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
NCS = os.path.join(ROOT, "build", "ncs")
OUT = os.path.join(ROOT, "build", "nwn_doom.erf")

RES_TYPES = {"tga": 3, "wav": 4, "nss": 2009, "ncs": 2010}
TYPE_EXT = {v: k for k, v in RES_TYPES.items()}
HEADER_SIZE = 160
KEY_SIZE = 24
RES_SIZE = 8


def write_erf(out_path, paths, file_type=b"ERF "):
    """Write an ERF-family archive (ERF, HAK, MOD) containing the given files."""
    entries = []
    for path in paths:
        name = os.path.basename(path)
        resref, ext = name.lower().rsplit(".", 1)
        if len(resref) > 16:
            raise SystemExit(f"{name}: resref longer than 16 characters")
        with open(path, "rb") as f:
            entries.append((resref, RES_TYPES[ext], f.read()))

    count = len(entries)
    off_keys = HEADER_SIZE
    off_res = off_keys + count * KEY_SIZE
    off_data = off_res + count * RES_SIZE

    today = datetime.date.today()
    header = struct.pack(
        "<4s4sIIIIIIIII",
        file_type, b"V1.0",
        0, 0,                 # language count, localized string size
        count,
        off_keys,             # no localized strings: they would start here
        off_keys, off_res,
        today.year - 1900, today.timetuple().tm_yday - 1,
        0,                    # description strref (0, as Beamdog's nwn_erf writes it)
    ) + b"\0" * 116

    keys = b""
    res_list = b""
    data = b""
    for i, (resref, rtype, blob) in enumerate(entries):
        keys += struct.pack("<16sIHH", resref.encode("ascii"), i, rtype, 0)
        res_list += struct.pack("<II", off_data + len(data), len(blob))
        data += blob

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(header + keys + res_list + data)
    print(f"wrote {out_path} ({count} resources)")


def build(out_path):
    # Sources always; compiled scripts too when tools/build.py produced them.
    paths = [os.path.join(SRC, f) for f in sorted(os.listdir(SRC)) if f.lower().endswith(".nss")]
    if os.path.isdir(NCS):
        paths += [os.path.join(NCS, f) for f in sorted(os.listdir(NCS)) if f.lower().endswith(".ncs")]
    write_erf(out_path, paths)


def read_erf(path):
    """Return [(resref, restype, data)] for every resource in an ERF/HAK/MOD."""
    with open(path, "rb") as f:
        blob = f.read()
    _sig, _ver, _lc, _ls, count, _ol, off_keys, off_res = struct.unpack_from("<4s4sIIIIII", blob, 0)
    entries = []
    for i in range(count):
        resref, _rid, rtype, _ = struct.unpack_from("<16sIHH", blob, off_keys + i * KEY_SIZE)
        offset, size = struct.unpack_from("<II", blob, off_res + i * RES_SIZE)
        entries.append((resref.rstrip(b"\0").decode("latin-1").lower(), rtype, blob[offset:offset + size]))
    return entries


def list_erf(path):
    with open(path, "rb") as f:
        blob = f.read()
    sig, ver, _lc, _ls, count, _ol, off_keys, off_res = struct.unpack_from("<4s4sIIIIII", blob, 0)
    print(f"{sig.decode()} {ver.decode()}: {count} entries")
    for i in range(count):
        resref, _rid, rtype, _ = struct.unpack_from("<16sIHH", blob, off_keys + i * KEY_SIZE)
        offset, size = struct.unpack_from("<II", blob, off_res + i * RES_SIZE)
        name = resref.rstrip(b"\0").decode()
        first = ""
        if TYPE_EXT.get(rtype) == "nss":
            first = blob[offset:offset + size].split(b"\n", 1)[0].decode("ascii", "replace").strip()
        print(f"  {name}.{TYPE_EXT.get(rtype, rtype)}  {size:6d} bytes  {first}")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--list":
        list_erf(sys.argv[2])
    else:
        build(OUT)
