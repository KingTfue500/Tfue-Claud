"""Synthesizes every sound effect (mono 44.1 kHz) and writes sounds.json."""
import json
import os
import subprocess
import tempfile
import wave
import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'assets', 'onepiece')
OUT = os.path.join(ROOT, 'sounds')
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(42)


def t(sec):
    return np.linspace(0, sec, int(SR * sec), endpoint=False)


def env(n, attack=0.01, release=0.3, sustain=0.0):
    a = int(SR * attack)
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, max(1, a))
    tt = np.linspace(0, 1, n)
    return e * np.exp(-tt / max(0.01, release)) * (1 - sustain) + e * sustain


def noise(n):
    return rng.standard_normal(n)


def lowpass(x, cutoff):
    # one-pole lowpass, cutoff may be an array
    alpha = np.clip(2 * np.pi * np.asarray(cutoff) / SR, 0, 1) * np.ones(len(x))
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def sweep(f0, f1, sec, shape=np.sin):
    tt = t(sec)
    f = np.geomspace(f0, f1, len(tt))
    phase = 2 * np.pi * np.cumsum(f) / SR
    return shape(phase)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def write(name, x):
    x = norm(x)
    # short fade to avoid clicks
    f = min(256, len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        path = tmp.name
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path, '-c:a', 'libvorbis', '-q:a', '5', os.path.join(OUT, name + '.ogg')], check=True)
    os.remove(path)


def make():
    # Rubber stretch: rising wobbly "boing" with a creak.
    sec = 0.45
    tt = t(sec)
    f = 180 + 520 * (tt / sec) ** 0.7 + 40 * np.sin(tt * 90)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.01, 0.4)
    s += 0.25 * lowpass(noise(len(tt)), 2500) * env(len(tt), 0.005, 0.15)
    write('stretch', s)
    # Snap back: fast falling twang.
    sec = 0.3
    s = sweep(900, 120, sec) * env(int(SR * sec), 0.002, 0.18) + 0.4 * lowpass(noise(int(SR * sec)), 4000) * env(int(SR * sec), 0.001, 0.04)
    write('snap', s)
    # Punch: thump + crack.
    sec = 0.35
    n = int(SR * sec)
    s = sweep(160, 45, sec) * env(n, 0.002, 0.12) * 1.4 + lowpass(noise(n), 3500) * env(n, 0.001, 0.05)
    write('punch', s)
    # Heavy impact: deep boom with rumble tail.
    sec = 1.6
    n = int(SR * sec)
    s = sweep(120, 28, sec) * env(n, 0.004, 0.45) * 1.5 + lowpass(noise(n), np.geomspace(3000, 120, n)) * env(n, 0.002, 0.5) * 1.2
    write('heavy_impact', s)
    # Gatling: rapid punches.
    sec = 1.5
    n = int(SR * sec)
    s = np.zeros(n)
    hit = sweep(200, 60, 0.08) * env(int(SR * 0.08), 0.001, 0.04) + lowpass(noise(int(SR * 0.08)), 3000) * env(int(SR * 0.08), 0.001, 0.02)
    for i in range(0, n - len(hit), int(SR * 0.055)):
        s[i:i + len(hit)] += hit * (0.7 + 0.3 * rng.random())
    write('gatling', s * env(n, 0.01, 1.2, 0.6))
    # Whoosh: bandpassed noise sweep.
    sec = 0.6
    n = int(SR * sec)
    s = lowpass(noise(n), np.concatenate([np.geomspace(400, 5000, n // 2), np.geomspace(5000, 600, n - n // 2)]))
    s = highpass(s, 300) * np.sin(np.linspace(0, np.pi, n)) ** 2
    write('whoosh', s)
    # Slash: metallic shing.
    sec = 0.8
    n = int(SR * sec)
    s = sum(np.sin(2 * np.pi * f * t(sec)) * np.exp(-t(sec) * d) for f, d in ((2200, 5), (3300, 7), (4700, 9), (6100, 12)))
    s += highpass(lowpass(noise(n), 9000), 2500) * env(n, 0.001, 0.08) * 2
    write('slash', s)
    # Big slash: whoosh + shing + low thump.
    sec = 1.2
    n = int(SR * sec)
    w = lowpass(noise(n), np.geomspace(6000, 400, n)) * env(n, 0.01, 0.4)
    ring = sum(np.sin(2 * np.pi * f * t(sec)) * np.exp(-t(sec) * d) for f, d in ((1800, 3), (2700, 4), (3900, 6)))
    write('big_slash', w * 1.5 + ring * 0.6 + sweep(110, 40, sec) * env(n, 0.002, 0.2))
    # Sheathe: click + slide.
    sec = 0.5
    n = int(SR * sec)
    s = highpass(lowpass(noise(n), 7000), 2000) * np.linspace(1, 0, n) ** 2 * 0.6
    s[int(SR * 0.42):int(SR * 0.42) + 400] += np.sin(np.linspace(0, 80, 400)) * np.linspace(1, 0, 400)
    write('sheathe', s)
    # Tornado: swirling filtered wind.
    sec = 2.4
    n = int(SR * sec)
    cut = 700 + 500 * np.sin(np.linspace(0, 14 * np.pi, n))
    s = lowpass(noise(n), cut) * np.sin(np.linspace(0, np.pi, n)) ** 0.5
    write('tornado', s)
    # Kick: whoosh into thud.
    sec = 0.4
    n = int(SR * sec)
    s = lowpass(noise(n), np.geomspace(800, 4000, n)) * env(n, 0.05, 0.1) * 0.6
    s[int(SR * 0.1):] += (sweep(140, 50, sec - 0.1) * env(n - int(SR * 0.1), 0.002, 0.08)) * 1.4
    write('kick', s)
    # Fire: crackling roar.
    sec = 1.6
    n = int(SR * sec)
    s = lowpass(noise(n), 900) * np.sin(np.linspace(0, np.pi, n)) ** 0.6
    crack = np.zeros(n)
    for _ in range(60):
        i = rng.integers(0, n - 300)
        crack[i:i + 300] += noise(300) * np.exp(-np.linspace(0, 8, 300)) * rng.random()
    write('fire', s + highpass(crack, 1500) * 0.6)
    # Fire blast: explosion of flame.
    sec = 1.4
    n = int(SR * sec)
    s = lowpass(noise(n), np.geomspace(5000, 300, n)) * env(n, 0.005, 0.5) * 1.3 + sweep(90, 30, sec) * env(n, 0.003, 0.3)
    write('fire_blast', s)
    # Steam: hiss.
    sec = 1.2
    n = int(SR * sec)
    write('steam', highpass(noise(n), 3500) * env(n, 0.05, 0.8, 0.3))
    # Inflate: rising rubbery balloon.
    sec = 0.9
    n = int(SR * sec)
    f = np.geomspace(90, 260, n) + 8 * np.sin(np.linspace(0, 60, n))
    s = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3 + np.sin(2 * np.pi * np.cumsum(f) / SR)
    write('inflate', lowpass(s, 1800) * env(n, 0.05, 0.9, 0.4))
    # Bounce: boing.
    sec = 0.5
    n = int(SR * sec)
    f = 140 + 260 * np.exp(-t(sec) * 9) + 30 * np.sin(t(sec) * 70)
    write('bounce', np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.002, 0.35))
    # Drums of Liberation: "dum-dum-dum" taiko pattern.
    sec = 2.2
    n = int(SR * sec)
    s = np.zeros(n)
    drum_t = t(0.5)
    drum = (np.sin(2 * np.pi * np.cumsum(np.geomspace(110, 50, len(drum_t))) / SR) * np.exp(-drum_t * 7)
            + lowpass(noise(len(drum_t)), 600) * np.exp(-drum_t * 25) * 0.6)
    for k, start in enumerate((0.0, 0.32, 0.64, 1.1, 1.26, 1.42, 1.58)):
        i = int(SR * start)
        end = min(n, i + len(drum))
        s[i:end] += drum[:end - i] * (1.2 if k in (0, 3) else 0.8)
    write('drums', s)
    # Lightning: crack + rolling thunder.
    sec = 2.4
    n = int(SR * sec)
    s = highpass(noise(n), 2000) * env(n, 0.001, 0.05) * 2 + lowpass(noise(n), np.geomspace(2000, 80, n)) * env(n, 0.02, 0.9) * 1.5
    write('lightning', s)
    # Haki: dark resonant hum.
    sec = 1.0
    n = int(SR * sec)
    tt = t(sec)
    s = (np.sin(2 * np.pi * 55 * tt) + 0.5 * np.sin(2 * np.pi * 82.5 * tt) + 0.3 * np.sin(2 * np.pi * 110 * tt * (1 + 0.01 * np.sin(tt * 30))))
    write('haki', s * env(n, 0.05, 0.6) + lowpass(noise(n), 300) * env(n, 0.01, 0.3) * 0.5)
    # Conqueror's: massive pressure wave.
    sec = 2.6
    n = int(SR * sec)
    tt = t(sec)
    s = sum(np.sin(2 * np.pi * f * tt) * a for f, a in ((36, 1.0), (54, 0.6), (73, 0.4), (147, 0.2)))
    s = s * env(n, 0.08, 1.2) + lowpass(noise(n), np.geomspace(4000, 100, n)) * env(n, 0.005, 0.6) * 1.5
    write('conqueror', s)
    # Transformation: rising power surge.
    sec = 1.8
    n = int(SR * sec)
    tt = t(sec)
    f = np.geomspace(80, 640, n)
    s = sum(np.sin(2 * np.pi * np.cumsum(f * m) / SR) / m for m in (1, 1.5, 2, 3))
    s = s * np.linspace(0.2, 1, n) ** 2 * env(n, 0.01, 2.0, 0.6) + lowpass(noise(n), np.geomspace(300, 6000, n)) * np.linspace(0, 1, n) ** 3
    write('form_up', s)
    # Boss roar: growling formant noise.
    sec = 2.0
    n = int(SR * sec)
    tt = t(sec)
    growl = np.sign(np.sin(2 * np.pi * (70 + 20 * np.sin(tt * 6)) * tt)) * 0.5
    s = lowpass(noise(n) * 0.6 + growl, 900 + 600 * np.sin(np.linspace(0, np.pi, n))) * np.sin(np.linspace(0, np.pi, n)) ** 0.4
    write('boss_roar', s)
    # Eating a fruit: crunch crunch.
    sec = 0.9
    n = int(SR * sec)
    s = np.zeros(n)
    for start in (0.0, 0.3, 0.6):
        i = int(SR * start)
        m = int(SR * 0.18)
        s[i:i + m] += highpass(noise(m), 1200) * np.exp(-np.linspace(0, 6, m))
    write('eat_fruit', s)


def sounds_json():
    names = ['stretch', 'snap', 'punch', 'heavy_impact', 'gatling', 'whoosh', 'slash', 'big_slash', 'sheathe', 'tornado', 'kick', 'fire',
             'fire_blast', 'steam', 'inflate', 'bounce', 'drums', 'lightning', 'haki', 'conqueror', 'form_up', 'boss_roar', 'eat_fruit']
    data = {n: {'sounds': ['onepiece:' + n], 'subtitle': 'subtitles.onepiece.' + n} for n in names}
    json.dump(data, open(os.path.join(ROOT, 'sounds.json'), 'w'), indent=2)


if __name__ == '__main__':
    make()
    sounds_json()
    print('sounds done')
