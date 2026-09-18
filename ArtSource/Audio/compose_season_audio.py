"""Original offline sound design for repeatable courtyard moods; no samples."""
import json
import numpy as np
from compose_farm_audio import RATE, RNG, SOURCE, add, filtered_noise, save


def render(kind):
    duration = 48
    output = np.zeros((duration * RATE, 2))
    if kind == "after_rain":
        # Scattered water drops after rainfall, with soft resonant splashes.
        for when in np.sort(RNG.uniform(0, duration, 65)):
            t = np.arange(int(RATE * .43)) / RATE
            pitch = RNG.uniform(800, 1450)
            phase = 2 * np.pi * pitch * (t + .12 * (1-np.exp(-t/.025)))
            drop = np.sin(phase) * np.exp(-t / .032) * .12
            drop += filtered_noise(len(t), 500, 5400) * np.exp(-t/.065) * .09
            drop *= 1 - np.exp(-t/.0018)
            add(output, drop, when, RNG.uniform(.3, .8), RNG.uniform(-.55,.55), True)
        rms, peak = .005, .06
    else:
        # Broad, irregular leaf and woven-rack rustles. No musical chime loop.
        for when in np.sort(RNG.uniform(0, duration, 19)):
            seconds = RNG.uniform(1.2, 3.4)
            t = np.arange(int(RATE * seconds)) / RATE
            rustle = filtered_noise(len(t), 1100, 6300)
            rustle *= np.sin(np.pi * t/seconds)**2
            rustle *= .35 + .12*np.sin(t*11.7) + .06*np.sin(t*31.5)
            add(output, rustle, when, RNG.uniform(.09,.18), RNG.uniform(-.7,.7), True)
        rms, peak = .009, .045
    return save("season_"+kind, output, True, rms, peak)


if __name__ == "__main__":
    results = [render(kind) for kind in ["drying", "after_rain"]]
    (SOURCE / "seasons.json").write_text(json.dumps(results, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(results, indent=2))
