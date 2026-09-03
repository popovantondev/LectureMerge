"""Development check: compare spoken PCM samples against the original audio.

Decode from the beginning and trim on OUTPUT. Input-side fast seeking can have
different AAC preroll at a seek boundary and is unsuitable for this comparison.
"""
from pathlib import Path
import argparse
import array
import json
import math
import subprocess

root = Path(__file__).resolve().parent.parent
ffmpeg = root / 'vendor/ffmpeg'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('result', type=Path)
parser.add_argument('--positions', nargs='+', type=float, required=True, help='Audible speech positions in seconds; avoid silence')
args = parser.parse_args()
source, result = args.source, args.result


def pcm(path, stream, start):
    raw = subprocess.check_output([
        str(ffmpeg), '-v', 'error', '-i', str(path), '-ss', str(start),
        '-map', stream, '-t', '2', '-ac', '1', '-ar', '8000', '-f', 's16le', '-'
    ])
    values = array.array('h')
    values.frombytes(raw)
    return values


(root / 'build').mkdir(exist_ok=True)
measurements = []
for language, original, output_stream, positions in [
    ('RU', source.with_suffix('.ru.siri.voice.wav'), '0:a:0', args.positions),
    ('DE', source, '0:a:1', args.positions),
]:
    for position in positions:
        before = pcm(original, '0:a:0', position)
        after = pcm(result, output_stream, position)
        indexes = range(1000, min(len(before), len(after)) - 1000, 8)
        energy = sum(before[i] ** 2 for i in indexes)
        if energy == 0 or len(indexes) < 10:
            raise ValueError(f'No measurable speech at {position}s in {original}; choose another position')

        def correlation(offset):
            other = sum(after[i + offset] ** 2 for i in indexes)
            cross = sum(before[i] * after[i + offset] for i in indexes)
            return cross / math.sqrt(max(1, energy * other))

        # Search every sample: voiced speech may have several local correlation peaks.
        offset = max(range(-960, 961), key=correlation)
        measurement = dict(track=language, position_seconds=position,
                           lag_ms=offset / 8, correlation=round(correlation(offset), 6))
        measurements.append(measurement)
        print(measurement, flush=True)

(root / 'build/audio-sync-results.json').write_text(json.dumps(measurements, indent=2))
assert all(abs(m['lag_ms']) <= 2 and m['correlation'] > 0.9 for m in measurements)
