"""Extract Doom HUD and weapon art from a WAD into an NWN hak.

  py tools/wad_to_hak.py [path\\to\\doom2.wad]

- Decodes the status bar, number fonts, arms panel and first-person weapon
  sprites (Doom picture format + PLAYPAL palette).
- Writes them as 32-bit TGAs, scaled up 4x with nearest-neighbour so the
  pixels stay crisp, named dm_<lump> (e.g. dm_stbar.tga).
- Converts the weapon and imp sounds (Doom DMX or WAV lumps) to mono
  16-bit WAVs named dm_<lump> (e.g. dm_dspistol.wav).
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
WAD = os.environ.get("DOOM_WAD", r"E:\Users\Krzysiek\Downloads\freedoom-0.13.0\freedoom2.wad")
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

# Sounds, played by the scripts as dm_<lump> (e.g. dm_dspistol).
SOUND_LUMPS = ["DSPISTOL", "DSSHOTGN", "DSPUNCH", "DSFIRSHT", "DSFIRXPL"]

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


def decode_sound(blob):
    """Doom (DMX) or WAV sound lump -> (rate, mono 16-bit samples) or None if unusable.

    Some repacked WADs carry 58-byte stubs: a WAV header with no audio. Those,
    and anything else truncated or empty, return None.
    """
    if blob[:4] == b"RIFF" and blob[8:12] == b"WAVE":
        pos, fmt, data = 12, None, None
        while pos + 8 <= len(blob):
            cid, size = struct.unpack_from("<4sI", blob, pos)
            body = blob[pos + 8:pos + 8 + size]
            if len(body) < size:
                return None  # truncated
            if cid == b"fmt ":
                fmt = struct.unpack_from("<HHIIHH", body, 0)
            elif cid == b"data":
                data = body
            pos += 8 + size + (size & 1)
        if not fmt or not data or fmt[0] != 1 or fmt[5] not in (8, 16):
            return None
        _tag, channels, rate, _bps, _align, bits = fmt
        if bits == 8:
            frames = [(s - 128) << 8 for s in data]
        else:
            frames = list(struct.unpack(f"<{len(data) // 2}h", data[:len(data) // 2 * 2]))
        if channels > 1:  # down-mix: PlaySound is positional and wants mono
            frames = [sum(frames[i:i + channels]) // channels
                      for i in range(0, len(frames) - channels + 1, channels)]
        return (rate, frames) if len(frames) >= 100 else None

    if len(blob) >= 8:
        fmt, rate, count = struct.unpack_from("<HHI", blob, 0)
        data = blob[8:8 + count]
        if fmt == 3 and len(data) == count and count > 132:
            data = data[16:-16]  # DMX pads 16 samples at each end
            return rate, [(s - 128) << 8 for s in data]
    return None


def write_wav(path, rate, samples):
    data = struct.pack(f"<{len(samples)}h", *samples)
    header = struct.pack("<4sI4s4sIHHIIHH4sI", b"RIFF", 36 + len(data), b"WAVE",
                         b"fmt ", 16, 1, 1, rate, rate * 2, 2, 16, b"data", len(data))
    with open(path, "wb") as f:
        f.write(header + data)


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

    sounds, bad_sounds = 0, []
    for name in SOUND_LUMPS:
        decoded = decode_sound(lumps[name]) if name in lumps else None
        if decoded is None:
            bad_sounds.append(name)
            continue
        path = os.path.join(ART_DIR, PREFIX + name.lower() + ".wav")
        write_wav(path, *decoded)
        written.append(path)
        sounds += 1
    print(f"converted {sounds} of {len(SOUND_LUMPS)} sounds")
    if bad_sounds:
        print(f"warning: no usable audio for {', '.join(bad_sounds)} (missing, or empty stubs as in "
              "some repacked WADs); the game stays silent for those. The official freedoom2.wad has them.")

    vfx_path, vfx_constants = build_vfx_2da(ART_DIR)
    written.append(vfx_path)
    write_art_include(sprites, vfx_constants)
    build_erf.write_erf(HAK_OUT, written, b"HAK ")

    hak_dir = os.path.join(NWN_USER, "hak")
    if os.path.isdir(hak_dir):
        shutil.copy2(HAK_OUT, os.path.join(hak_dir, "nwn_doom.hak"))
        print(f"installed {os.path.join(hak_dir, 'nwn_doom.hak')}")
    else:
        print(f"hak folder not found ({hak_dir}); copy build/nwn_doom.hak there yourself")


# Custom visualeffects.2da rows, appended after the game's last row.
# Scripts play sounds by applying these effects: PlaySound runs through
# an object's action queue and was dropped when the queue was busy, while
# effects play reliably. (constant name, template row or None, sound resref)
VFX_FIRST_ROW = 10100
VFX_ROWS = [
    ("DOOM_VFX_PISTOL",     None, "dm_dspistol"),
    ("DOOM_VFX_SHOTGUN",    None, "dm_dsshotgn"),
    ("DOOM_VFX_PUNCH",      None, "dm_dspunch"),
    ("DOOM_VFX_FIRESHOT",   None, "dm_dsfirsht"),
    # VFX_IMP_FLAME_S without its sound: the fireball trail plays it every
    # 0.05 s, and its stock sound flooded the sound channels.
    ("DOOM_VFX_FIRETRAIL",  61,   "****"),
    # VFX_IMP_FLAME_M with the Doom fireball explosion sound.
    ("DOOM_VFX_FIREEXPL",   60,   "dm_dsfirxpl"),
]


def build_vfx_2da(out_dir):
    """Game's visualeffects.2da plus VFX_ROWS; returns {constant: row}."""
    import nwn_key
    base = None
    for resref, rtype, bif, idx in nwn_key.all_entries():
        if resref == "visualeffects" and rtype == nwn_key.EXT_TO_TYPE["2da"]:
            base = nwn_key.read_bif_resource(bif, idx).decode("latin-1")
    if base is None:
        raise SystemExit("visualeffects.2da not found in the game data")

    lines = base.split("\r\n") if "\r\n" in base else base.split("\n")
    while lines and not lines[-1].strip():
        lines.pop()
    columns = lines[2].split()
    rows = {}
    for line in lines[3:]:
        parts = line.split()
        if parts:
            rows[int(parts[0])] = parts[1:] + ["****"] * (len(columns) - len(parts) + 1)
    last = max(rows)
    if last >= VFX_FIRST_ROW:
        raise SystemExit(f"visualeffects.2da already has row {last}; move VFX_FIRST_ROW past it")
    for n in range(last + 1, VFX_FIRST_ROW):  # keep the row numbering contiguous
        lines.append(f"{n} " + " ".join(["****"] * len(columns)))

    sound_col = columns.index("SoundImpact")
    constants = {}
    for i, (name, template, sound) in enumerate(VFX_ROWS):
        row = VFX_FIRST_ROW + i
        values = list(rows[template]) if template is not None else ["****"] * len(columns)
        values[columns.index("Label")] = name
        if template is None:
            values[columns.index("Type_FD")] = "F"
            values[columns.index("OrientWithGround")] = "0"
        values[sound_col] = sound
        lines.append(f"{row} " + " ".join(values))
        constants[name] = row

    path = os.path.join(out_dir, "visualeffects.2da")
    with open(path, "w", newline="\r\n") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote visualeffects.2da with {len(VFX_ROWS)} Doom effect rows from {VFX_FIRST_ROW}")
    return path, constants


def write_art_include(sprites, vfx_constants):
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
        "// Rows added to visualeffects.2da in the hak; applying one plays its sound.",
    ] + [f"const int {name} = {row};" for name, row in vfx_constants.items()] + [
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
