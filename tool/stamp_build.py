"""Stamps build/web with a unique build id after `flutter build web`.

Replaces __BUILD_ID__ in index.html and flutter_bootstrap.js and writes
build.json, which the running app polls to notice a new deploy (see
web/index.html).
"""

import json
import pathlib
import subprocess
import time

web = pathlib.Path(__file__).resolve().parent.parent / 'build' / 'web'
try:
    sha = subprocess.check_output(
        ['git', 'rev-parse', '--short', 'HEAD'], text=True
    ).strip()
except Exception:
    sha = 'local'
build_id = f"{time.strftime('%Y%m%d%H%M%S')}-{sha}"

for name in ('index.html', 'flutter_bootstrap.js'):
    path = web / name
    text = path.read_text()
    if '__BUILD_ID__' not in text:
        raise SystemExit(f'{name}: no __BUILD_ID__ placeholder')
    path.write_text(text.replace('__BUILD_ID__', build_id))

(web / 'build.json').write_text(json.dumps({'id': build_id}))
print(build_id)
