#!/usr/bin/env python3
"""Feature E -- restyle the native menu chrome by REPLACING TEXTURES ONLY.

The in-game screens are drawn by the native engine from texture atlases, so the
only safe way to restyle them is to swap the art while keeping every texture's
dimensions, format and alpha channel byte-for-byte compatible. No code, no
layout, no click regions, no logic are touched.

The stock chrome is greyscale, which makes this clean: each pixel's LUMINANCE is
remapped through a palette ramp matching the launcher's identity, and its ALPHA
is copied through untouched. Shape, bevels and 9-slice geometry are therefore
preserved exactly -- only hue changes.

Deliberately excluded (see ALLOW/why): world-list and server-list content,
status dots, scrollbars, item/armor/anvil icons, and anything belonging to an
unrelated screen.
"""
import os
import sys

from PIL import Image

SRC_DIR = 'assets/images/gui/newgui'

# Menu chrome shared by Play / Settings / Skins and the surrounding frame.
ALLOW = [
    # buttons
    'NormalButtonStroke.png', 'NormalButtonNoStroke.png', 'NormalButtonThin.png',
    'NormalButtonThinStroke.png', 'buttonNew.png',
    'DarkButtonStroke.png', 'DarkButtonNoStroke.png', 'DarkButtonThin.png',
    'ButtonWithBorder.png', 'ButtonWithBorderHover.png', 'ButtonWithBorderPressed.png',
    'classic-button.png', 'classic-button-hover.png', 'classic-button-pressed.png',
    # tabs
    'TabBack.png', 'TabFront.png', 'LeftTabFront.png', 'MiddleTabFront.png',
    'RightTabFront.png', 'TabBackInGame.png', 'TabBackInGameLeftMost.png',
    'TabFrontInGame.png', 'TabFrontInGameLeftMost.png',
    # panels / frame
    'dialog-background-atlas.png', 'TopBar.png',
]

# Kept stock ON PURPOSE. Listed explicitly so the exclusion is reviewable.
EXCLUDE_REASON = {
    'World.png': 'world list row icon', 'WorldDemoScreen.png': 'world list art',
    'Realms.png': 'server list', 'Friends.png': 'server list',
    'FriendsDiversity.png': 'server list', 'Local.png': 'server list',
    'onlineLight.png': 'server status dot', 'offlineLight.png': 'server status dot',
    'Dot1.png': 'status dot', 'Dot2.png': 'status dot', 'Dot3.png': 'status dot',
    'ScrollBox.png': 'list scrollbar', 'ScrollGutter.png': 'list scrollbar',
    'scrollbarBG.png': 'list scrollbar', 'touchScrollBox.png': 'list scrollbar',
    'newTouchScrollBox.png': 'list scrollbar',
}

# luminance -> colour ramp (launcher identity: deep slate-teal, green highlight)
RAMP = [
    (0,   (8, 14, 18)),
    (64,  (18, 38, 34)),
    (128, (27, 64, 52)),
    (192, (48, 104, 78)),
    (232, (96, 160, 64)),
    (255, (126, 211, 33)),
]


def remap(lum):
    for i in range(len(RAMP) - 1):
        l0, c0 = RAMP[i]
        l1, c1 = RAMP[i + 1]
        if l0 <= lum <= l1:
            t = 0.0 if l1 == l0 else (lum - l0) / float(l1 - l0)
            return tuple(int(round(c0[j] + (c1[j] - c0[j]) * t)) for j in range(3))
    return RAMP[-1][1]


def main(apk_root, out_root):
    lut = [remap(i) for i in range(256)]
    made = []
    for name in ALLOW:
        src = os.path.join(apk_root, SRC_DIR, name)
        if not os.path.exists(src):
            sys.exit('!! missing stock texture: %s' % src)
        im = Image.open(src)
        orig_size, orig_mode = im.size, im.mode
        im = im.convert('RGBA')
        px = im.load()
        w, h = im.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue                      # fully transparent: leave as-is
                lum = (r * 299 + g * 587 + b * 114) // 1000
                nr, ng, nb = lut[lum]
                px[x, y] = (nr, ng, nb, a)        # alpha preserved exactly

        rel = '%s/%s' % (SRC_DIR, name)
        dst = os.path.join(out_root, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        im.save(dst, 'PNG', optimize=True)

        chk = Image.open(dst)
        assert chk.size == orig_size, 'dimension drift on %s' % name
        made.append(rel)
        print('  recoloured %-34s %s %s->RGBA' % (name, orig_size, orig_mode))

    with open(os.path.join(out_root, 'MANIFEST.txt'), 'w') as f:
        f.write('\n'.join(made) + '\n')
    print('  %d textures restyled; %d deliberately left stock'
          % (len(made), len(EXCLUDE_REASON)))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
