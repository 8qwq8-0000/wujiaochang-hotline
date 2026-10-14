"""Regenerate the project's original prototype cues (Python standard library only)."""
from pathlib import Path
import math
import struct
import wave

OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio/sfx/enemy_ui"
RATE = 22050
CUES = {"pickup": [700, 1000], "equip": [450, 750], "full": [160, 120], "enemy_attack": [220, 330]}

def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, frequencies in CUES.items():
        samples = []
        for frequency in frequencies:
            length = int(RATE * 0.07)
            samples.extend(
                int(8500 * math.sin(2 * math.pi * frequency * i / RATE)
                    * min(i / (RATE * 0.005), 1) * (1 - i / length) ** 2)
                for i in range(length)
            )
        with wave.open(str(OUTPUT / (name + ".wav")), "wb") as audio:
            audio.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            audio.writeframes(struct.pack("<" + "h" * len(samples), *samples))

if __name__ == "__main__":
    main()
