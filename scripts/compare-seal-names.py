#!/usr/bin/env python3
"""Compare les noms scellés (Contents/_CodeSignature/CodeResources, files2) aux noms
réellement présents sur disque, octet pour octet, et indique leur forme Unicode.

Usage : python3 -I scripts/compare-seal-names.py /chemin/Neomas.app

Un nom scellé en NFC qui revient en NFD après copie apparaît à la fois comme
« scellé mais absent » et « présent mais non scellé » : c'est exactement ce que
codesign rapporte en « a sealed resource is missing or invalid ».
Code de sortie 1 si les ensembles diffèrent ou si un chemin non ASCII existe.
"""
import os
import plistlib
import re
import sys
import unicodedata
from collections import Counter

NESTED = re.compile(r'^(Frameworks|PlugIns|XPCServices|Helpers|Library/LoginItems)/[^/]+\.(framework|app|xpc|appex)$')


def form(name):
    if name.isascii():
        return 'ascii'
    nfc, nfd = unicodedata.normalize('NFC', name), unicodedata.normalize('NFD', name)
    if nfc == nfd:
        return 'non-ascii, normalization-invariant'
    return 'NFC' if name == nfc else 'NFD' if name == nfd else 'mixed'


def main(app):
    contents = os.path.join(app, 'Contents')
    with open(os.path.join(contents, '_CodeSignature', 'CodeResources'), 'rb') as fh:
        files2 = plistlib.load(fh)['files2']

    sealed = set()
    for key, value in files2.items():
        if isinstance(value, dict) and value.get('optional'):
            continue
        sealed.add(key)

    on_disk = set()
    non_ascii = []
    for root, dirs, files in os.walk(contents):
        rel_root = os.path.relpath(root, contents)
        if rel_root == '.':
            rel_root = ''
        for name in dirs + files:
            rel = os.path.join(rel_root, name) if rel_root else name
            if not rel.isascii():
                non_ascii.append(rel)
        if rel_root == '_CodeSignature' or rel_root == 'MacOS' or rel_root.startswith('MacOS/'):
            dirs[:] = []
            continue
        keep = []
        for d in dirs:
            rel = os.path.join(rel_root, d) if rel_root else d
            if NESTED.match(rel):
                on_disk.add(rel)  # bundle imbriqué : scellé par cdhash, en bloc
            else:
                keep.append(d)
        dirs[:] = keep
        for name in files:
            rel = os.path.join(rel_root, name) if rel_root else name
            if name == '.DS_Store' or rel in ('Info.plist', 'PkgInfo', 'CodeResources'):
                continue
            on_disk.add(rel)

    sealed_non_ascii = [k for k in sealed if not k.isascii()]
    print(f'app: {app}')
    print(f'non-ASCII paths under Contents/: {len(non_ascii)}')
    print(f'  on-disk forms: {dict(Counter(form(p) for p in non_ascii))}')
    print(f'  seal (CodeResources files2) non-ASCII keys: {len(sealed_non_ascii)}, '
          f'forms: {dict(Counter(form(k) for k in sealed_non_ascii))}')
    sample = next((p for p in sorted(non_ascii) if form(p) in ('NFC', 'NFD')), None)
    if sample:
        print(f'  sample on disk : {sample!r}')
        print(f'  sample bytes   : {os.path.basename(sample).encode("utf-8", "surrogateescape").hex(" ")}')

    missing = sorted(sealed - on_disk)
    added = sorted(on_disk - sealed)
    print(f'sealed but missing on disk (exact bytes): {len(missing)}')
    for k in missing[:10]:
        print(f'  - {k}  [{form(k)}]')
    print(f'on disk but not sealed (exact bytes): {len(added)}')
    for k in added[:10]:
        print(f'  + {k}  [{form(k)}]')
    ok = not missing and not added and not non_ascii
    print('RESULT:', 'names match the seal, all ASCII' if ok else 'MISMATCH or non-ASCII path present')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
