"""Original, deterministic farm score and sound design; no sampled recordings.

Requires numpy/scipy/soundfile and ffmpeg. All frequencies, notes and envelopes
are authored here. Runtime uses pre-rendered files, never synthesis services.
"""
from pathlib import Path
import json
import subprocess
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, fftconvolve

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/Audio"
OUTPUT = ROOT / "Game/art/audio"
RATE = 48000
RNG = np.random.default_rng(91734)
SCORE = []


def frequency(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def filtered_noise(n, low, high):
    noise = RNG.standard_normal(n)
    return sosfilt(butter(2, [low, high], fs=RATE, btype="bandpass", output="sos"), noise)


def pluck(note, duration=6.0, soft=1.0):
    t = np.arange(int(duration * RATE)) / RATE
    f = frequency(note)
    y = np.zeros_like(t)
    # String modes decay at different rates; subdued upper modes keep it warm.
    for mode in range(1, 15):
        a = np.sin(np.pi * mode * .19) / (mode ** 1.25)
        decay = (2.9 / (1 + .27 * mode)) * (220 / f) ** .18
        y += a * np.sin(2 * np.pi * f * mode * (1 + .000018 * mode * mode) * t) * np.exp(-t / decay)
    body = .055 * np.sin(2 * np.pi * 173 * t) * np.exp(-t / .06)
    contact = filtered_noise(len(t), 1100, 4500) * .017 * np.exp(-t / .012)
    y = (y + body + contact) * (1 - np.exp(-t / .004))
    y *= np.minimum(1, (duration - t) / .08)
    return y * soft


def flute(note, duration):
    t = np.arange(int(duration * RATE)) / RATE
    breath = filtered_noise(len(t), 900, 4200)
    f = frequency(note)
    bend = -.007 * np.exp(-t / .10) + .0025 * np.sin(2 * np.pi * 4.6 * t) * (1 - np.exp(-t / .7))
    phase = 2 * np.pi * f * np.cumsum(1 + bend) / RATE
    y = np.sin(phase) + .15 * np.sin(2 * phase + .2) + .055 * np.sin(3 * phase)
    envelope = np.minimum(t / .17, 1) * np.minimum((duration - t) / .34, 1)
    envelope = np.sin(np.clip(envelope, 0, 1) * np.pi / 2) ** 2
    return (y + .075 * breath) * envelope * (.93 + .07 * np.sin(t * 2.4))


def add(buffer, sound, when, volume, pan=0.0, wrap=False):
    stereo = sound[:, None] * np.array([np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)]) * volume
    start = round(when * RATE)
    if wrap:
        indices = (np.arange(len(sound)) + start) % len(buffer)
        np.add.at(buffer, indices, stereo)
    elif start < len(buffer):
        count = min(len(sound), len(buffer) - start)
        buffer[start:start + count] += stereo[:count]


def room(buffer, circular=False):
    # Sparse early reflections and a low-level, dark diffuse tail.
    result = buffer.copy()
    for delay, gain in [(.043, .09), (.079, .065), (.137, .045), (.223, .029), (.347, .019)]:
        offset = int(delay * RATE)
        echo = np.roll(buffer[:, ::-1], offset, axis=0)
        if not circular:
            echo[:offset] = 0
        result += echo * gain
    tail_n = int(1.7 * RATE)
    tail_t = np.arange(tail_n) / RATE
    for channel in range(2):
        impulse = filtered_noise(tail_n, 180, 3300) * np.exp(-tail_t / .40)
        impulse[:int(.045 * RATE)] = 0
        impulse *= .065 / np.sqrt(np.sum(impulse * impulse))
        wet = fftconvolve(buffer[:, channel], impulse)
        result[:, channel] += wet[:len(buffer)]
        if circular:
            result[:len(wet) - len(buffer), channel] += wet[len(buffer):]
    return result


def save(name, signal, loop, rms_target, peak_limit):
    signal -= signal.mean(axis=0)
    rms = np.sqrt(np.mean(signal ** 2))
    scale = min(rms_target / max(rms, 1e-10), peak_limit / max(abs(signal).max(), 1e-10))
    signal *= scale
    if not loop:
        fade = min(round(.012 * RATE), len(signal) // 4)
        signal[:fade] *= np.linspace(0, 1, fade)[:, None]
        signal[-fade:] *= np.linspace(1, 0, fade)[:, None]
    master = SOURCE / "masters" / (name + ".wav")
    sf.write(master, signal, RATE, subtype="PCM_24")
    if loop:
        target = OUTPUT / (name + ".ogg")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(master), "-c:a", "libvorbis", "-q:a", "5", str(target)], check=True)
    else:
        target = OUTPUT / (name + ".wav")
        sf.write(target, signal, RATE, subtype="PCM_16")
    decoded, decoded_rate = sf.read(target)
    rms_db = 20 * np.log10(max(np.sqrt(np.mean(decoded ** 2)), 1e-12))
    peak_db = 20 * np.log10(max(abs(decoded).max(), 1e-12))
    boundary = float(np.max(abs(decoded[0] - decoded[-1])))
    return {"name": name, "file": str(target.relative_to(ROOT)), "seconds": len(decoded) / decoded_rate,
            "rate": decoded_rate, "channels": 2, "loop": loop, "rms_dbfs": round(rms_db, 2),
            "peak_dbfs": round(peak_db, 2), "loop_boundary_delta": boundary,
            "origin": "original score and deterministic synthesis; no external samples"}


def music():
    duration = 128
    output = np.zeros((duration * RATE, 2))
    # D major pentatonic, 60 BPM, eight spacious four-bar phrases.
    # Event tuple: offset in phrase, MIDI pitch, sounding duration.
    phrases = [
        [(1, 66, 2), (4, 69, 2), (7, 71, 2.5), (11, 69, 3)],
        [(1, 66, 2.2), (4, 64, 2), (7, 62, 4)],
        [(1, 69, 2), (4, 74, 2.3), (7, 76, 2), (10, 74, 3.4)],
        [(1, 71, 2.8), (5, 69, 2.3), (9, 66, 4)],
        [(1, 66, 1.6), (3, 69, 2), (6, 71, 3), (10, 74, 3)],
        [(1, 76, 2.4), (5, 74, 2.2), (8, 71, 3), (12, 69, 2)],
        [(1, 66, 2), (4, 69, 2.3), (8, 64, 3.2)],
        [(1, 66, 2.4), (5, 64, 2.4), (9, 62, 4.5)],
    ]
    for phrase, notes in enumerate(phrases):
        for when, note, length in notes:
            at = phrase * 16 + when
            instrument = "flute" if phrase in (2, 3, 5, 6) else "plucked_zither"
            wave = flute(note, length) if instrument == "flute" else pluck(note, 7)
            add(output, wave, at, .16 if instrument == "flute" else .30, .18 if instrument == "flute" else -.16, True)
            SCORE.append({"time": at, "midi_note": note, "duration": length, "instrument": instrument})
    roots = [50, 50, 59, 57, 50, 54, 57, 50]
    for bar in range(32):
        base = roots[bar // 4]
        for offset, note, level in [(0, base, .16), (1.6, base + 12, .105), (3.0, base + 7, .075)]:
            if bar % 4 == 3 and offset > 0:
                continue  # Audible breathing space at phrase endings.
            at = bar * 4 + offset + .04 * np.sin(bar * 1.3 + offset)
            add(output, pluck(note), at, level * RNG.uniform(.89, 1.05), -.28, True)
            SCORE.append({"time": round(at, 3), "midi_note": note, "duration": 6, "instrument": "accompaniment_zither"})
    return room(output, True)


def ambience(night):
    duration = 64
    n = duration * RATE
    t = np.arange(n) / RATE
    output = np.zeros((n, 2))
    # Periodic Fourier-shaped air bed: no filter discontinuity at the loop seam.
    frequencies = np.fft.rfftfreq(n, 1 / RATE)
    for channel in range(2):
        phase = RNG.uniform(0, 2 * np.pi, len(frequencies))
        envelope = 1 / np.maximum(frequencies, 70) ** .70
        envelope *= np.exp(-(frequencies / 2700) ** 2) * (1 - np.exp(-(frequencies / 100) ** 2))
        noise = np.fft.irfft(envelope * np.exp(1j * phase), n)
        noise /= np.std(noise)
        output[:, channel] = noise * (.018 + .007 * np.sin(2 * np.pi * t / 32 + channel) ** 2)
    if night:
        for at in [3, 8.8, 15, 22.5, 32, 40, 47.6, 57]:
            length = 1.25
            local = np.arange(int(length * RATE)) / RATE
            carrier = np.sin(2 * np.pi * 2850 * local) + .3 * np.sin(2 * np.pi * 3350 * local)
            pulse = np.maximum(0, np.sin(2 * np.pi * 19 * local)) ** 8
            envelope = np.sin(np.pi * local / length) ** 2
            add(output, carrier * pulse * envelope, at, .007, RNG.uniform(-.7, .7), True)
    else:
        for at in [4, 13.5, 25, 39, 54]:
            for syllable in range(3):
                local = np.arange(int(.17 * RATE)) / RATE
                f = 1800 + syllable * 190 + 420 * np.sin(np.pi * local / .17)
                wave = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.sin(np.pi * local / .17) ** 2
                add(output, wave, at + .22 * syllable, .014, np.sin(at) * .6, True)
    return output


def effects():
    results = {}
    for name, duration in [("sow", .48), ("water", 1.15), ("harvest", .65), ("ui", .13)]:
        n = int(duration * RATE)
        t = np.arange(n) / RATE
        output = np.zeros((n, 2))
        if name == "sow":
            for at in [.035, .13, .22]:
                wave_t = np.arange(int(.14 * RATE)) / RATE
                wave = filtered_noise(len(wave_t), 180, 1800) * np.exp(-wave_t / .035)
                add(output, wave, at, .28, RNG.uniform(-.25, .25))
        elif name == "water":
            envelope = np.sin(np.pi * t / duration) ** 1.8
            noise = filtered_noise(n, 350, 4800) * envelope
            output += noise[:, None] * .13
            for at in [.12, .23, .39, .55, .68, .85]:
                local = np.arange(int(.14 * RATE)) / RATE
                phase = 2 * np.pi * (720 * local - 1100 * local ** 2)
                wave = np.sin(phase) * np.exp(-local / .03) * (1 - np.exp(-local / .002))
                add(output, wave, at, .065, RNG.uniform(-.4, .4))
        elif name == "harvest":
            noise = filtered_noise(n, 250, 2600) * np.exp(-t / .10) * (1 - np.exp(-t / .018))
            output += noise[:, None] * .14
            add(output, pluck(74, .45), .13, .08, -.1)
            add(output, pluck(81, .30), .24, .045, .1)
        else:
            wave = (np.sin(2 * np.pi * 520 * t) + .22 * np.sin(2 * np.pi * 830 * t)) * np.exp(-t / .018)
            output += (wave * .10 * (1 - np.exp(-t / .003)))[:, None]
        results[name] = output
    return results


if __name__ == "__main__":
    (SOURCE / "masters").mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    reports = [save("courtyard_theme", music(), True, .040, .22)]
    reports += [save("ambience_" + name, ambience(night), True, .018, .075) for name, night in [("day", False), ("night", True)]]
    reports += [save(name, data, False, .040, .22) for name, data in effects().items()]
    (SOURCE / "score.json").write_text(json.dumps({"title": "田间慢声", "tempo_bpm": 60, "duration": 128, "scale": "D major pentatonic", "events": SCORE}, indent=2), encoding="utf-8")
    (SOURCE / "audio-report.json").write_text(json.dumps(reports, indent=2), encoding="utf-8")
    print(json.dumps(reports, indent=2))
