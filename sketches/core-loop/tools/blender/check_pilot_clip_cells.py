"""Check the renderer's frame choices without Blender; print all eleven roles per pilot."""
import argparse
import ast
import json
from pathlib import Path
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
TABLES = HERE.parents[1] / 'src/presentation/clips'


def renderer_functions():
    source = HERE / 'render_pilot_clips.py'
    tree = ast.parse(source.read_text())
    functions = ast.Module(body=[node for node in tree.body if isinstance(node, ast.FunctionDef)], type_ignores=[])
    scope = {'Path': Path, 'CELL_W': 480, 'CELL_H': 384}
    exec(compile(functions, str(source), 'exec'), scope)
    return scope


def beats(keys):
    runs = []
    previous = None
    for key in sorted(keys, key=lambda key: key['frame']):
        pose = {field: value for field, value in key.items() if field not in ('frame', 'note')}
        if not runs or pose != previous:
            runs.append([key])
        else:
            runs[-1].append(key)
        previous = pose
    return runs


def check(require_all=False):
    frames = renderer_functions()['clip_frames']
    roster = json.loads((TABLES / 'roster.json').read_text())
    failures = []
    for pilot in roster['pilots']:
        path = TABLES / (pilot + '.json')
        table = json.loads(path.read_text()) if path.exists() else None
        if table is None and require_all:
            failures.append(pilot + ': no committed pose table')
        for name in roster['new']:
            definition = (table or {}).get('clips', {}).get(name, {})
            end = definition.get('end', roster['end_frames'][pilot][name])
            chosen = frames(name, SimpleNamespace(frame_range=(0, end - 1)), table, name in roster['loops'])
            contact = definition.get('contact', {}).get('frame')
            runs = beats(definition.get('keys', []))
            first = next((run[0]['frame'] for run in runs if any(
                key['frame'] == contact or key.get('contact') or 'contact' in key.get('note', '').lower()
                for key in run)), None)
            print('%s %-14s %s contact_beat=%s%s' % (pilot, name, chosen, first,
                  ' NO_TABLE (fallback only)' if table is None else ''))
            if len(chosen) != 5 or chosen != sorted(chosen):
                failures.append('%s %s: expected five ordered cells' % (pilot, name))
            if first is not None and first not in chosen:
                failures.append('%s %s: misses contact beat %d' % (pilot, name, first))
    for failure in failures:
        print('FAIL:', failure)
    print('PILOT_CLIP_CELLS: %s (66 roles, %d committed tables)' % (
        'FAIL' if failures else 'PASS', sum((TABLES / (p + '.json')).exists() for p in roster['pilots'])))
    return not failures


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--require-all-tables', action='store_true')
    raise SystemExit(0 if check(parser.parse_args().require_all_tables) else 1)
