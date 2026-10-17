"""Extract Doom HUD and weapon art from a WAD into an NWN hak.

  py tools/wad_to_hak.py [path\\to\\doom2.wad]

- Decodes the status bar, number fonts, arms panel and first-person weapon
  sprites (Doom picture format + PLAYPAL palette).
- Writes them as 32-bit TGAs, scaled up 4x with nearest-neighbour so the
  pixels stay crisp, named dm_<lump> (e.g. dm_stbar.tga).
- Generates src/doom_art.nss with each weapon frame's screen position,
  computed the way Doom places player sprites above the status bar.
- Packs build/nwn_doom.hak and copies it to the NWN hak folder.

Works with id's doom.wad/doom2.wad and with Freedoom. Lumps that are
1x1 placeholders (Freedoom has no status bar face) are skipped.
Paths can be overridden with DOOM_WAD and NWN_USER.
"""
import os
import re
import shutil
import struct
import sys

import build_erf

ROOT = build_erf.ROOT
WAD = os.environ.get("DOOM_WAD", r"E:\Users\Krzysiek\Downloads\doom2WAD\doom2.wad")
NWN_USER = os.environ.get("NWN_USER", r"G:\nwnData")
ART_DIR = os.path.join(ROOT, "build", "art")
HAK_OUT = os.path.join(ROOT, "build", "nwn_doom.hak")
NSS_OUT = os.path.join(ROOT, "src", "doom_art.nss")

SCALE = 4
PREFIX = "dm_"

# Status bar art, positioned by doom_inc.nss using Doom's own layout.
HUD_LUMPS = (["STBAR", "STARMS", "STTPRCNT", "STTMINUS"]
             + [f"STTNUM{i}" for i in range(10)]
             + [f"STYSNUM{i}" for i in range(10)]
             + [f"STGNUM{i}" for i in range(2, 8)])
# First-person weapon frames: name pattern -> found frames are all extracted.
WEAPON_RE = re.compile(r"^(PUNG|PISG|PISF|SHTG|SHTF)[A-Z]0$")

# Doom draws player sprites at x = 1 - leftoffset and, with the status bar
# shown (view height 168, centre 84), at y = 16 - topoffset.
SPRITE_X0 = 1
SPRITE_Y0 = 16


def read_wad(path):
    with open(path, "rb") as f:
        data = f.read()
    kind, count, off = struct.unpack_from("<4sii", data, 0)
    if kind not in (b"IWAD", b"PWAD"):
        raise SystemExit(f"{path}: not a WAD file")
    lumps = {}
    for i in range(count):
        pos, size, name = struct.unpack_from("<ii8s", data, off + 16 * i)
        lumps[name.rstrip(b"\0").decode("latin-1").upper()] = data[pos:pos + size]
    return lumps


def decode_picture(blob, palette):
    """Doom picture -> (width, height, leftoff, topoff, rows of RGBA tuples)."""
    w, h, left, top = struct.unpack_from("<hhhh", blob, 0)
    pixels = [[(0, 0, 0, 0)] * w for _ in range(h)]
    for x in range(w):
        p = struct.unpack_from("<I", blob, 8 + 4 * x)[0]
        last_top = -1
        while blob[p] != 0xFF:
            top_delta = blob[p]
            # Tall patches: a delta not above the previous one is relative.
            row = top_delta + last_top if top_delta <= last_top else top_delta
            last_top = row
            length = blob[p + 1]
            for i in range(length):
                y = row + i
                if 0 <= y < h:
                    idx = blob[p + 3 + i]
                    r, g, b = palette[idx * 3:idx * 3 + 3]
                    pixels[y][x] = (r, g, b, 255)
            p += length + 4
    return w, h, left, top, pixels


def write_tga(path, w, h, pixels, scale):
    sw, sh = w * scale, h * scale
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, sw, sh, 32, 8)
    out = bytearray(header)
    # Bottom-up rows (the TGA default origin), BGRA.
    for y in range(sh - 1, -1, -1):
        src = pixels[y // scale]
        for x in range(sw):
            r, g, b, a = src[x // scale]
            out += bytes((b, g, r, a))
    with open(path, "wb") as f:
        f.write(out)


def main():
    wad = sys.argv[1] if len(sys.argv) > 1 else WAD
    lumps = read_wad(wad)
    if "PLAYPAL" not in lumps:
        raise SystemExit("WAD has no PLAYPAL palette")
    palette = lumps["PLAYPAL"][:768]
    print(f"{wad}: {len(lumps)} lumps" + (" (Freedoom)" if "FREEDOOM" in lumps else ""))

    shutil.rmtree(ART_DIR, ignore_errors=True)
    os.makedirs(ART_DIR)

    names = [n for n in HUD_LUMPS if n in lumps]
    names += sorted(n for n in lumps if WEAPON_RE.match(n))
    written, sprites, skipped = [], {}, []
    for name in names:
        w, h, left, top, pixels = decode_picture(lumps[name], palette)
        if w <= 1 or h <= 1:
            skipped.append(name)
            continue
        resref = PREFIX + name.lower()
        path = os.path.join(ART_DIR, resref + ".tga")
        write_tga(path, w, h, pixels, SCALE)
        written.append(path)
        if WEAPON_RE.match(name):
            sprites[resref] = (SPRITE_X0 - left, SPRITE_Y0 - top, w, h)
    missing = [n for n in HUD_LUMPS if n not in lumps]
    print(f"converted {len(written)} images; skipped placeholders: {skipped or 'none'}; missing: {missing or 'none'}")

    write_art_include(sprites)
    build_erf.write_erf(HAK_OUT, written, b"HAK ")

    hak_dir = os.path.join(NWN_USER, "hak")
    if os.path.isdir(hak_dir):
        shutil.copy2(HAK_OUT, os.path.join(hak_dir, "nwn_doom.hak"))
        print(f"installed {os.path.join(hak_dir, 'nwn_doom.hak')}")
    else:
        print(f"hak folder not found ({hak_dir}); copy build/nwn_doom.hak there yourself")


def write_art_include(sprites):
    top = min(y for _, y, _, _ in sprites.values())
    lines = [
        "// doom_art: GENERATED by tools/wad_to_hak.py from the WAD - do not edit.",
        "// Weapon sprite placement in Doom's 320x200 screen space.",
        "",
        "#include \"nw_inc_nui\"",
        "",
        "// Topmost virtual y any weapon frame reaches; the HUD window starts here.",
        f"const float DOOM_ART_TOP = {float(top):.1f};",
        "",
        "// Rect of weapon frame sResRef inside the HUD window at scale fScale.",
        "json DoomSpriteRect(string sResRef, float fScale)",
        "{",
        "    float x = 0.0; float y = 0.0; float w = 0.0; float h = 0.0;",
    ]
    first = True
    for resref, (x, y, w, h) in sorted(sprites.items()):
        kw = "if" if first else "else if"
        first = False
        lines.append(f"    {kw} (sResRef == \"{resref}\") {{ x = {x:.1f}; y = {y:.1f}; w = {w:.1f}; h = {h:.1f}; }}")
    lines += [
        "    return NuiRect(x * fScale, (y - DOOM_ART_TOP) * fScale, w * fScale, h * fScale);",
        "}",
        "",
        "// TRUE if the WAD provided this frame.",
        "int DoomHasSprite(string sResRef)",
        "{",
        "    return " + " || ".join(f"sResRef == \"{r}\"" for r in sorted(sprites)) + ";",
        "}",
        "",
    ]
    with open(NSS_OUT, "w", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"wrote {NSS_OUT} ({len(sprites)} weapon frames, top y {top})")


if __name__ == "__main__":
    main()
