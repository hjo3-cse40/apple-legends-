"""Rebuild original objective chimes and OS-synthesized placeholder callouts (macOS).
Runtime only needs the committed WAV files, on any platform.
"""
from pathlib import Path
import math
import struct
import subprocess
import wave

DEST = Path(__file__).resolve().parents[1] / 'audio/objective'
DEST.mkdir(parents=True, exist_ok=True)
LINES = {
    'capture_cyan': 'Cyan team captured the point.',
    'capture_amber': 'Amber team captured the point.',
    'cyan_30': 'Cyan team. Thirty seconds to victory. Push the point!',
    'amber_30': 'Amber team. Thirty seconds to victory. Push the point!',
    'cyan_10': 'Cyan team. Ten seconds remaining!',
    'amber_10': 'Amber team. Ten seconds remaining!',
    'five': 'Five.', 'four': 'Four.', 'three': 'Three.', 'two': 'Two.', 'one': 'One.',
    'overtime': 'Overtime! Clear the point!',
}
for name, line in LINES.items():
    subprocess.run(['say', '-v', 'Samantha', '-r', '205', '-o', str(DEST / (name + '.wav')),
                    '--file-format=WAVE', '--data-format=LEI16@22050', line], check=True)
for name, notes in {'capture_cyan_chime': [523, 659, 784],
                    'capture_amber_chime': [784, 659, 523],
                    'contest_chime': [330, 311], 'overtime_chime': [440, 554, 440, 554]}.items():
    samples = []
    for note in notes:
        duration = 0.14
        for i in range(int(22050 * duration)):
            t = i / 22050
            envelope = min(1, t / .008) * math.exp(-t * 16)
            value = .38 * envelope * (math.sin(math.tau * note * t) + .15 * math.sin(math.tau * note * 2 * t))
            samples.append(round(value * 32767))
    with wave.open(str(DEST / (name + '.wav')), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(22050)
        output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
