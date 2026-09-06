import argparse
import hashlib
import json
from pathlib import Path


def summarize(directory):
    report = json.loads((directory / 'report.json').read_text())
    trials = []
    for result in report['trials']:
        log = directory / f"trial-{result['trial']:03}" / 'events.ndjson'
        events = [json.loads(line) for line in log.read_text().splitlines()]
        frames = [frame for event in events if event['kind'] == 'combat_segment' for frame in event['frames']]
        gap_start = None
        longest = 0
        for frame in frames:
            now = frame['active_seconds']
            if not frame['targets']:
                if gap_start is None:
                    gap_start = now
                longest = max(longest, now - gap_start)
            else:
                gap_start = None
        trials.append({
            'trial': result['trial'], 'outcome': result['outcome'],
            'active_seconds': result['active_seconds'],
            'result_labels': result.get('result_labels', []),
            'frames': len(frames),
            'targetless_fraction': sum(not frame['targets'] for frame in frames) / max(1, len(frames)),
            'longest_targetless_active_seconds': longest,
            'pause_check': result.get('pause_check'),
        })
    return {
        'directory': str(directory), 'configuration': report['configuration'],
        'source_identity': hashlib.sha256(json.dumps(report['source_hashes'], sort_keys=True).encode()).hexdigest(),
        'passed': report['passed'], 'cleanup_errors': report['cleanup_errors'],
        'source_unchanged': report['source_unchanged'], 'controller_unchanged': report['controller_unchanged'],
        'trials': trials,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directories', nargs='+', type=Path)
    args = parser.parse_args()
    print(json.dumps([summarize(p) for p in args.directories], indent=2))
