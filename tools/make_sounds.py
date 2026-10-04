#!/usr/bin/env python3
"""마물의 작은 마을 효과음·배경음 합성기.

외부 음원 없이 사인·삼각·사각파, 잡음, Karplus-Strong 현 모델만으로 만든다.
결과물(assets/audio)은 이 스크립트와 함께 CC0 1.0 으로 공개한다.

실행: python3 tools/make_sounds.py   (numpy, oggenc 필요)
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(20261003)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, sustain_level=0.0):
    """간단한 ADSR(초 단위)."""
    e = np.zeros(n)
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = max(ai, 1)
    e[:ai] = np.linspace(0, 1, ai)
    end_d = min(n, ai + di)
    e[ai:end_d] = np.linspace(1, sustain_level, end_d - ai)
    e[end_d:] = sustain_level
    if ri > 0 and n > ri:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def sine(f, sec):
    return np.sin(2 * np.pi * f * t_axis(sec))


def tri(f, sec):
    ph = (f * t_axis(sec)) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def square(f, sec, duty=0.5):
    ph = (f * t_axis(sec)) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def pluck(f, sec, damp=0.996):
    n = int(SR * sec)
    p = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = damp * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return out


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    base = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        base += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        base -= 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((base + (octave - 4) * 12) / 12)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(dst, src, at):
    i = int(at * SR)
    end = min(len(dst), i + len(src))
    dst[i:end] += src[: end - i]


def normalize(x, peak=0.8):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path, x):
    tmp = path.replace(".ogg", ".tmp.wav")
    write_wav(tmp, x)
    subprocess.run(["oggenc", "-Q", "-q", "3", "-o", path, tmp], check=True)
    os.remove(tmp)


# ------------------------------------------------------------------ 효과음

def sfx():
    out = {}
    # 버튼: 짧고 부드러운 '톡'
    n = int(SR * 0.06)
    out["click"] = normalize(sine(1050, 0.06) * decay(n, 0.015) + 0.3 * sine(1580, 0.06) * decay(n, 0.01), 0.45)
    # 배치: 나무 '쿵'
    n = int(SR * 0.22)
    body = sine(150, 0.22) * decay(n, 0.05) + 0.5 * sine(95, 0.22) * decay(n, 0.08)
    out["place"] = normalize(body + 0.35 * lowpass(noise(0.22), 1800) * decay(n, 0.02), 0.75)
    # 망치: 짧은 '똑'
    n = int(SR * 0.09)
    out["hammer"] = normalize(sine(520, 0.09) * decay(n, 0.012) + 0.6 * lowpass(noise(0.09), 3500) * decay(n, 0.008), 0.5)
    # 완성: 종소리 아르페지오
    x = np.zeros(int(SR * 1.0))
    for i, nm in enumerate(["C6", "E6", "G6", "C7"]):
        f = note(nm)
        nn = int(SR * 0.6)
        bell = (sine(f, 0.6) + 0.4 * sine(f * 2.01, 0.6) + 0.2 * sine(f * 3.0, 0.6)) * decay(nn, 0.18)
        place(x, bell, i * 0.09)
    out["build_done"] = normalize(x, 0.6)
    # 강화: 위로 올라가는 반짝임
    sec = 0.55
    tt = t_axis(sec)
    f = 500 + 1400 * (tt / sec) ** 1.5
    ph = 2 * np.pi * np.cumsum(f) / SR
    n = len(tt)
    out["upgrade"] = normalize(np.sin(ph) * env(n, 0.01, 0.4, 0.3, 0.12, 0.3) + 0.3 * sine(note("C7"), sec) * decay(n, 0.2), 0.55)
    # 석궁: 현 튕김 + 바람
    n = int(SR * 0.28)
    tw = pluck(196, 0.28, 0.985) * decay(n, 0.09)
    wh = lowpass(noise(0.28), 2500) * env(n, 0.03, 0.15, 0.0, 0.05)
    out["bow"] = normalize(tw + 0.5 * wh, 0.5)
    # 명중: 둔탁한 '퍽'
    n = int(SR * 0.12)
    out["hit"] = normalize(sine(230, 0.12) * decay(n, 0.025) + 0.7 * lowpass(noise(0.12), 2200) * decay(n, 0.015), 0.55)
    # 기사 쓰러짐: 내려가는 '뿅' + 쇠 달그락
    sec = 0.5
    tt = t_axis(sec)
    f = 520 * (1 - 0.6 * tt / sec)
    ph = 2 * np.pi * np.cumsum(f) / SR
    n = len(tt)
    clank = np.zeros(n)
    for at, ff in [(0.18, 1900), (0.27, 2400), (0.34, 1700)]:
        m = int(SR * 0.08)
        place(clank, sine(ff, 0.08) * decay(m, 0.015), at)
    out["knight_down"] = normalize(np.sin(ph) * env(n, 0.005, 0.3, 0.0, 0.1) + 0.35 * clank, 0.55)
    # 성 피격: 낮은 '쿵'
    n = int(SR * 0.3)
    out["castle_hit"] = normalize(sine(70, 0.3) * decay(n, 0.1) + 0.6 * lowpass(noise(0.3), 600) * decay(n, 0.05), 0.7)
    # 습격 시작: 뿔나팔 두 음
    x = np.zeros(int(SR * 1.2))
    for at, nm, ln in [(0.0, "G3", 0.35), (0.38, "C4", 0.75)]:
        f = note(nm)
        nn = int(SR * ln)
        horn = lowpass(square(f, ln, 0.35) + 0.5 * square(f * 2, ln, 0.4), 1400) * env(nn, 0.04, 0.1, 0.0, 0.12, 0.8)
        place(x, horn, at)
    out["raid_start"] = normalize(x, 0.6)
    # 승리 팡파르
    x = np.zeros(int(SR * 1.7))
    seq = [("C5", 0.0, 0.18), ("E5", 0.18, 0.18), ("G5", 0.36, 0.18), ("C6", 0.54, 0.9)]
    for nm, at, ln in seq:
        f = note(nm)
        nn = int(SR * ln)
        place(x, (tri(f, ln) + 0.3 * square(f, ln, 0.25)) * env(nn, 0.01, 0.15, 0.0, 0.2, 0.6), at)
        place(x, 0.4 * tri(f / 2, ln) * env(nn, 0.01, 0.15, 0.0, 0.2, 0.6), at)
    out["victory"] = normalize(x, 0.6)
    # 패배: 내려가는 단조
    x = np.zeros(int(SR * 1.8))
    for i, nm in enumerate(["G4", "F4", "Eb4", "D4"]):
        f = note(nm)
        ln = 0.32 if i < 3 else 0.9
        nn = int(SR * ln)
        place(x, tri(f, ln) * env(nn, 0.02, 0.2, 0.0, 0.2, 0.5), i * 0.32)
    out["defeat"] = normalize(x, 0.55)
    return out


# ------------------------------------------------------------------ 배경음

def drum_kick():
    sec = 0.18
    tt = t_axis(sec)
    f = 110 * np.exp(-tt * 18) + 45
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * decay(len(tt), 0.06)


def drum_hat():
    n = int(SR * 0.05)
    return (noise(0.05) - lowpass(noise(0.05), 4000)) * decay(n, 0.012)


def music(bpm, bars, melody, chords, drums_level, lead="tri", seed_swing=0.0):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    x = np.zeros(int(SR * total) + SR)
    # 화음(부드러운 패드) + 베이스
    for i in range(bars):
        root, third, fifth = chords[i % len(chords)]
        at = i * 4 * beat
        ln = 4 * beat
        nn = int(SR * ln)
        pad = sum(tri(note(n), ln) for n in (third, fifth)) * env(nn, 0.25, 0.5, 0.0, 0.4, 0.55)
        place(x, 0.12 * lowpass(pad, 1200), at)
        for b in range(4):
            bl = beat * 0.9
            bn = int(SR * bl)
            place(x, 0.32 * tri(note(root), bl) * env(bn, 0.01, 0.2, 0.0, 0.08, 0.6), at + b * beat)
    # 멜로디
    t = 0.0
    for nm, ln in melody:
        dur = ln * beat
        if nm != "-":
            f = note(nm)
            nn = int(SR * dur * 0.95)
            wave_ = tri(f, dur * 0.95) if lead == "tri" else 0.6 * square(f, dur * 0.95, 0.3)
            place(x, 0.28 * wave_ * env(nn, 0.01, 0.12, 0.0, 0.06, 0.65), t)
        t += dur
    # 타악
    if drums_level > 0:
        for b in range(bars * 4):
            at = b * beat
            if b % 2 == 0:
                place(x, drums_level * 0.6 * drum_kick(), at)
            place(x, drums_level * 0.12 * drum_hat(), at + beat * 0.5)
    x = x[: int(SR * total)]
    # 이음매가 튀지 않게 끝 30ms 를 앞과 섞는다
    k = int(SR * 0.03)
    x[:k] = x[:k] * np.linspace(0, 1, k) + x[-k:] * np.linspace(1, 0, k)
    x = x[:-k]
    return normalize(lowpass(x, 6000), 0.6)


def village_theme():
    # C 장조 5음계, 느긋한 8마디 × 2
    chords = [("C3", "E4", "G4"), ("A2", "C4", "E4"), ("F2", "A3", "C4"), ("G2", "B3", "D4")]
    m1 = [("E5", 1), ("G5", 1), ("A5", 1), ("G5", 1), ("E5", 1.5), ("D5", 0.5), ("C5", 2),
          ("D5", 1), ("E5", 1), ("G5", 1), ("E5", 1), ("D5", 3), ("-", 1),
          ("C5", 1), ("D5", 1), ("E5", 1), ("G5", 1), ("A5", 1.5), ("G5", 0.5), ("E5", 2),
          ("D5", 1), ("C5", 1), ("D5", 1), ("E5", 1), ("C5", 3), ("-", 1)]
    return music(92, 16, m1 + m1, chords, 0.35)


def battle_theme():
    chords = [("A2", "C4", "E4"), ("F2", "A3", "C4"), ("G2", "B3", "D4"), ("E2", "G#3", "B3")]
    m = [("A4", 0.5), ("C5", 0.5), ("E5", 1), ("D5", 0.5), ("C5", 0.5), ("B4", 1),
         ("A4", 0.5), ("C5", 0.5), ("F5", 1), ("E5", 1), ("C5", 1),
         ("D5", 0.5), ("E5", 0.5), ("G5", 1), ("F5", 0.5), ("E5", 0.5), ("D5", 1),
         ("B4", 0.5), ("D5", 0.5), ("E5", 1), ("G#4", 1), ("E4", 1)]
    return music(132, 16, m * 4, chords, 0.8, lead="square")


def main():
    for name, x in sfx().items():
        write_wav(os.path.join(ROOT, "sfx", name + ".wav"), x)
    write_ogg(os.path.join(ROOT, "music", "village.ogg"), village_theme())
    write_ogg(os.path.join(ROOT, "music", "battle.ogg"), battle_theme())
    print("ok")


if __name__ == "__main__":
    main()
