#!/usr/bin/env python3
"""Patch the stock binary AndroidManifest.xml to front the game with LauncherActivity.

Two surgical edits, nothing else:
  1. detach the MAIN/LAUNCHER <intent-filter> from com.mojang.minecraftpe.MainActivity
  2. add a new <activity> for com.xzodomyx.LauncherActivity and give it that filter

MainActivity keeps its `minecraft:` VIEW/BROWSABLE filter, its NativeActivity
`android.app.lib_name` meta-data, and every one of its other attributes, so the game
itself starts exactly as it does on stock once the launcher hands off.

Design note: the new activity's attributes are *cloned from MainActivity's own*, so no
new framework attribute resource IDs are introduced. Only one new string
("com.xzodomyx.LauncherActivity") is appended to the pool, at the end, where it cannot
shift any index covered by the positional resource-map chunk.
"""
import sys

from axml import AXML

TYPE_STRING = 0x03
TYPE_INT_DEC = 0x10
SCREEN_ORIENTATION_PORTRAIT = 1

LAUNCHER_CLASS = 'com.xzodomyx.LauncherActivity'
GAME_ACTIVITY = 'com.mojang.minecraftpe.MainActivity'

# attributes worth carrying over from MainActivity onto the launcher
KEEP = {'label', 'name', 'screenOrientation', 'theme', 'configChanges'}


def main(src, dst):
    a = AXML(open(src, 'rb').read())

    app = a.find('application')
    assert len(app) == 1, 'expected exactly one <application>'
    app = app[0]

    game = None
    for act in a.find('activity', app):
        nm = a.attr(act, 'name')
        if nm and a.s(nm.data) == GAME_ACTIVITY:
            game = act
    assert game is not None, 'MainActivity not found'

    # --- 1. locate and detach the MAIN/LAUNCHER filter -------------------
    launcher_filter = None
    for f in list(game.children):
        if f.kind != 'el' or a.s(f.name) != 'intent-filter':
            continue
        acts = {a.s(a.attr(c, 'name').data) for c in f.children
                if c.kind == 'el' and a.s(c.name) == 'action' and a.attr(c, 'name')}
        cats = {a.s(a.attr(c, 'name').data) for c in f.children
                if c.kind == 'el' and a.s(c.name) == 'category' and a.attr(c, 'name')}
        if 'android.intent.action.MAIN' in acts and 'android.intent.category.LAUNCHER' in cats:
            launcher_filter = f
    assert launcher_filter is not None, 'MAIN/LAUNCHER intent-filter not found on MainActivity'
    game.children.remove(launcher_filter)
    print('  - detached MAIN/LAUNCHER filter from %s' % GAME_ACTIVITY)

    remaining = [a.s(c.name) for c in game.children if c.kind == 'el']
    print('  - MainActivity retains children: %s' % remaining)

    # --- 2. build the launcher activity ---------------------------------
    new_idx = a.pool.index(LAUNCHER_CLASS)
    print('  - string pool: %r at index %d (pool size %d)'
          % (LAUNCHER_CLASS, new_idx, len(a.pool.strings)))

    act = type(game)('el')
    act.line = game.line
    act.end_line = game.end_line
    act.ns = game.ns
    act.name = game.name           # reuse the existing "activity" string
    act.id_idx = act.class_idx = act.style_idx = 0

    for src_attr in game.attrs:
        nm = a.s(src_attr.name)
        if nm not in KEEP:
            continue
        at = src_attr.copy()
        if nm == 'name':
            at.raw = new_idx
            at.type = TYPE_STRING
            at.data = new_idx
        elif nm == 'screenOrientation':
            at.raw = 0xFFFFFFFF
            at.type = TYPE_INT_DEC
            at.data = SCREEN_ORIENTATION_PORTRAIT   # forced portrait, per spec
        act.attrs.append(at)

    kept = [a.s(x.name) for x in act.attrs]
    assert 'name' in kept and 'screenOrientation' in kept, 'attribute clone failed'
    print('  - launcher activity attributes: %s' % kept)

    act.children.append(launcher_filter)

    # insert directly after MainActivity so the file stays readable
    app.children.insert(app.children.index(game) + 1, act)

    out = a.serialize()
    open(dst, 'wb').write(out)
    print('  - wrote %s (%d bytes)' % (dst, len(out)))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
