"""Rebuild original mono robot Foley and energy-shot PCM assets (stdlib only)."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'art' / 'audio'
RATE = 44100

def write(name, duration, synth):
    rng = random.Random(42)
    samples = [synth(i / RATE, rng.uniform(-1, 1)) for i in range(round(duration * RATE))]
    peak = max(abs(value) for value in samples)
    # Peak headroom keeps overlapping footsteps and shots from clipping easily.
    pcm = b''.join(struct.pack('<h', round(value / peak * 0.72 * 32767)) for value in samples)
    with wave.open(str(ROOT / name), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm)

ROOT.mkdir(parents=True, exist_ok=True)
# Soft rubber contact, compact shell click, then a tiny actuator chirp.
write('robot_step.wav', 0.16, lambda t, n:
      (1-math.exp(-t*2200)) * math.exp(-t*55) * (0.58*math.sin(2*math.pi*155*t)+0.22*n)
      + 0.12*math.sin(2*math.pi*1150*t)*math.exp(-t*90)
      + (0.05*math.sin(2*math.pi*740*t)*math.exp(-(t-0.045)*55) if t >= 0.045 else 0))
# Crisp energy crack plus a descending resonant body, distinct from the player's rifle.
write('bot_shot.wav', 0.30, lambda t, n:
      (1-math.exp(-t*3000)) * (0.55*n*math.exp(-t*70)
      + 0.40*math.sin(2*math.pi*(950*t-950*t*t))*math.exp(-t*19)
      + 0.22*math.sin(2*math.pi*135*t)*math.exp(-t*26)))
# Brief rounded shield tick for local incoming damage.
write('shield_hit.wav', 0.19, lambda t, n:
      (1-math.exp(-t*1800)) * math.exp(-t*29)
      * (0.45*math.sin(2*math.pi*460*t)+0.18*math.sin(2*math.pi*690*t)+0.1*n))
