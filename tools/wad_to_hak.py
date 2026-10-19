"""Extract Doom HUD and weapon art from a WAD into an NWN hak.

  py tools/wad_to_hak.py [path\\to\\doom2.wad]

- Decodes the status bar, number fonts, arms panel, Doomguy faces and
  first-person weapon sprites (Doom picture format + PLAYPAL palette).
- Writes them as 32-bit TGAs, scaled up 4x with nearest-neighbour so the
  pixels stay crisp, named dm_<lump> (e.g. dm_stbar.tga).
- Converts the weapon and imp sounds (Doom DMX or WAV lumps) to mono
  16-bit WAVs named dm_<lump> (e.g. dm_dspistol.wav).
- Generates src/doom_art.nss with each weapon frame's screen position,
  computed the way Doom places player sprites above the status bar.
- Packs build/nwn_doom.hak and copies it to the NWN hak folder, if that
  is found (see tools/nwn_paths.py).

Works with id's doom.wad/doom2.wad and with Freedoom. Lumps that are
1x1 placeholders (Freedoom has no status bar face) are skipped.
The WAD can also be given with the DOOM_WAD environment variable.
"""
import os
import re
import shutil
import struct
import sys

import build_erf
import nwn_paths

ROOT = build_erf.ROOT
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
# Status bar faces: straight (health level 0-4, look 0-2), turned left/right,
# ouch, evil grin, rampage (firing), dead, god.
FACE_RE = re.compile(r"^STF(ST[0-4][0-2]|TL[0-4]0|TR[0-4]0|OUCH[0-4]|EVL[0-4]|KILL[0-4]|DEAD0|GOD0)$")

# Sounds, played by the scripts as dm_<lump> (e.g. dm_dspistol).
SOUND_LUMPS = ["DSPISTOL", "DSSHOTGN", "DSPUNCH", "DSFIRSHT", "DSFIRXPL"]

# Doom draws player sprites at x = 1 - leftoffset and, with the status bar
# shown (view height 168, centre 84), at y = 16 - topoffset.
SPRITE_X0 = 1
SPRITE_Y0 = 16
# Doom draws the status bar face at (143, 168), minus the image's offsets.
FACE_X0 = 143
FACE_Y0 = 168


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
    wad = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("DOOM_WAD")
    if not wad:
        raise SystemExit("usage: py tools/wad_to_hak.py path/to/freedoom2.wad (or set DOOM_WAD)")
    lumps = read_wad(wad)
    if "PLAYPAL" not in lumps:
        raise SystemExit("WAD has no PLAYPAL palette")
    palette = lumps["PLAYPAL"][:768]
    print(f"{wad}: {len(lumps)} lumps" + (" (Freedoom)" if "FREEDOOM" in lumps else ""))

    shutil.rmtree(ART_DIR, ignore_errors=True)
    os.makedirs(ART_DIR)

    names = [n for n in HUD_LUMPS if n in lumps]
    names += sorted(n for n in lumps if WEAPON_RE.match(n))
    names += sorted(n for n in lumps if FACE_RE.match(n))
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
        elif FACE_RE.match(name):
            sprites[resref] = (FACE_X0 - left, FACE_Y0 - top, w, h)
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

    written += write_cursor(ART_DIR)
    vfx_path, vfx_constants = build_vfx_2da(ART_DIR)
    written.append(vfx_path)
    write_art_include(sprites, vfx_constants)
    build_erf.write_erf(HAK_OUT, written, b"HAK ")

    user = nwn_paths.nwn_user(required=False)
    hak_dir = os.path.join(user, "hak") if user else ""
    if os.path.isdir(hak_dir):
        shutil.copy2(HAK_OUT, os.path.join(hak_dir, "nwn_doom.hak"))
        print(f"installed {os.path.join(hak_dir, 'nwn_doom.hak')}")
    else:
        print("NWN hak folder not found (set NWN_USER, see tools/nwn_paths.py); "
              "copy build/nwn_doom.hak there yourself")


# Gun mode uses the stock DM "kill" cursor (MOUSECURSOR_KILL), which players
# never see otherwise, and the hak replaces its image with a small red dot.
# Shots go to the HUD crosshair, not the pointer, but the sky cannot be
# clicked in targeting mode, so the dot shows where the pointer is (keep it
# on the ground or on monsters). Stock cursors click at their top-left pixel,
# so the dot sits there. (EE's custom cursor slots broke clicking in
# targeting mode.) Every stock cursor exists as TGA and DDS; both are replaced.
CURSOR_RESREFS = ["gui_mp_killu", "gui_mp_killd"]
CURSOR_SIZE = 32
CURSOR_DOT = (230, 40, 30, 255)      # Doom red
CURSOR_OUTLINE = (0, 0, 0, 255)


def cursor_pixels():
    """32x32 RGBA rows: a 4x4 dot with a 1-pixel outline in the top-left corner."""
    rows = [[(0, 0, 0, 0)] * CURSOR_SIZE for _ in range(CURSOR_SIZE)]
    for y in range(6):
        for x in range(6):
            rows[y][x] = CURSOR_DOT if 1 <= x <= 4 and 1 <= y <= 4 else CURSOR_OUTLINE
    return rows


def _rgb565(c):
    return ((c[0] >> 3) << 11) | ((c[1] >> 2) << 5) | (c[2] >> 3)


def _dxt5_block(px):
    """Encode 16 RGBA pixels as one DXT5 block (2 colours, 2 alpha levels:
    enough for flat-coloured cursor art)."""
    opaque = [p for p in px if p[3] >= 128]
    if not opaque:
        return bytes(16)  # all-zero block: alpha 0 everywhere
    lum = lambda c: c[0] * 3 + c[1] * 6 + c[2]
    c0, c1 = max(opaque, key=lum), min(opaque, key=lum)
    pal = [c0, c1,
           tuple((2 * a + b) // 3 for a, b in zip(c0, c1)),
           tuple((a + 2 * b) // 3 for a, b in zip(c0, c1))]
    color_bits = alpha_bits = 0
    for i, p in enumerate(px):
        ci = min(range(4), key=lambda k: sum((p[j] - pal[k][j]) ** 2 for j in range(3)))
        color_bits |= ci << (2 * i)
        alpha_bits |= (0 if p[3] >= 128 else 1) << (3 * i)  # a0 = 255, a1 = 0
    alpha = bytes([255, 0]) + alpha_bits.to_bytes(6, "little")
    color = struct.pack("<HHI", _rgb565(c0), _rgb565(c1), color_bits)
    return alpha + color


def write_nwn_dds(path, rows):
    """Square RGBA image in NWN's own DDS layout: a 20-byte header (width,
    height, 4 = DXT5, level-0 byte size, mean alpha) followed by DXT5 blocks
    for every mip level down to 1x1, as in the stock cursor DDS files."""
    size = len(rows)
    mean_alpha = sum(p[3] for r in rows for p in r) / (255.0 * size * size)
    levels, img = [], rows
    while True:
        n = len(img)
        blocks = b""
        for by in range(0, max(n, 4), 4):
            for bx in range(0, max(n, 4), 4):
                px = [img[min(by + y, n - 1)][min(bx + x, n - 1)] for y in range(4) for x in range(4)]
                blocks += _dxt5_block(px)
        levels.append(blocks)
        if n == 1:
            break
        img = [[img[2 * y][2 * x] for x in range(n // 2)] for y in range(n // 2)]  # nearest
    with open(path, "wb") as f:
        f.write(struct.pack("<IIIIf", size, size, 4, len(levels[0]), mean_alpha) + b"".join(levels))


def write_cursor(out_dir):
    rows = cursor_pixels()
    paths = []
    for resref in CURSOR_RESREFS:
        tga = os.path.join(out_dir, resref + ".tga")
        write_tga(tga, CURSOR_SIZE, CURSOR_SIZE, rows, 1)
        dds = os.path.join(out_dir, resref + ".dds")
        write_nwn_dds(dds, rows)
        paths += [tga, dds]
    print(f"wrote dot cursor {', '.join(CURSOR_RESREFS)} (TGA + DDS)")
    return paths


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
    top = min(y for r, (_, y, _, _) in sprites.items() if not r.startswith(PREFIX + "stf"))
    lines = [
        "// doom_art: GENERATED by tools/wad_to_hak.py from the WAD - do not edit.",
        "// Weapon frame and status bar face placement in Doom's 320x200 screen space.",
        "",
        "#include \"nw_inc_nui\"",
        "",
        "// Topmost virtual y any weapon frame reaches; the HUD window starts here.",
        f"const float DOOM_ART_TOP = {float(top):.1f};",
        "",
        "// Rect of weapon frame or face sResRef inside the HUD window at scale fScale.",
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
        "// TRUE if the WAD provided this weapon frame or face.",
        "int DoomHasSprite(string sResRef)",
        "{",
        "    return " + " || ".join(f"sResRef == \"{r}\"" for r in sorted(sprites)) + ";",
        "}",
        "",
    ]
    with open(NSS_OUT, "w", newline="\n") as f:
        f.write("\n".join(lines))
    faces = sum(1 for r in sprites if r.startswith(PREFIX + "stf"))
    print(f"wrote {NSS_OUT} ({len(sprites) - faces} weapon frames, {faces} faces, top y {top})")


if __name__ == "__main__":
    main()
