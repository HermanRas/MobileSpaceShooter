#!/usr/bin/env python3
"""The game's sounds (PLAN.md 14.1, 14.2), built from source in the tools container:

    tools/run.sh python3 -I tools/make_audio.py            # everything
    tools/run.sh python3 -I tools/make_audio.py fire_ boom  # only names starting so

- game/assets/audio/kenney/  Kenney's CC0 packs (art_src/audio/kenney/, the picks only): mixed to
                             mono, trimmed, faded and peak-normalised; loops made seamless.
- game/assets/audio/synth/   arcade SFX synthesised here (square, saw, noise and sweeps).
- game/assets/audio/music/   chiptune loops composed here from a seed: chords, bass, arpeggio,
                             a generated lead and drums, rendered so the end runs into the start.
                             A WAV in art_src/audio/music/ named after a track (menu.wav, from the
                             ART_PROMPT.md A.12 prompts) replaces it, crossfaded into a loop.

SFX are 16-bit mono WAV (cheap to play many times a second); music is Ogg Vorbis. Every output
is peak-normalised to -1 dBFS: how loud each plays is `data/audio.json`'s job (`db`).
Deterministic: the same script makes the same files.
"""

import os
import pathlib
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art_src" / "audio" / "kenney"
MUSIC_SRC = ROOT / "art_src" / "audio" / "music"
OUT = ROOT / "game" / "assets" / "audio"
SR = 44100


# ── files ────────────────────────────────────────────────────────────────────

def write_wav(path: pathlib.Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1 if x.ndim == 1 else 2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path: pathlib.Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        raw = pathlib.Path(tmp) / "music.wav"
        write_wav(raw, x)
        subprocess.run(["oggenc", "-Q", "-q", "4", "-o", str(path), str(raw)], check=True)


def read_wav(path: pathlib.Path) -> np.ndarray:
    """A 16-bit WAV at 44.1 kHz, as (samples, 2)."""
    with wave.open(str(path)) as w:
        channels = w.getnchannels()
        assert w.getframerate() == SR and w.getsampwidth() == 2, f"{path}: needs 16-bit, {SR} Hz"
        a = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768.0
    a = a.reshape(-1, channels)
    return np.repeat(a, 2, axis=1) if channels == 1 else a[:, :2]


def kenney(name: str) -> np.ndarray:
    """A Kenney source, decoded and mixed to mono."""
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "k.wav")
        subprocess.run(["oggdec", "-Q", "-o", raw, str(SRC / (name + ".ogg"))], check=True)
        with wave.open(raw) as w:
            channels = w.getnchannels()
            assert w.getframerate() == SR, name
            a = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768.0
    return a.reshape(-1, channels).mean(axis=1)


def finish(x: np.ndarray, trim_db: float = -50.0, fade_ms: float = 8.0) -> np.ndarray:
    """Trims the silence off both ends, fades the edges and peak-normalises to -1 dBFS."""
    level = np.abs(x)
    keep = np.where(level > level.max() * 10 ** (trim_db / 20))[0]
    if len(keep):
        x = x[max(keep[0] - int(0.002 * SR), 0):keep[-1] + 1]
    x = x.copy()
    fade = min(int(fade_ms / 1000 * SR), len(x) // 4)
    if fade > 0:
        x[-fade:] *= np.linspace(1.0, 0.0, fade)
    rise = min(int(0.002 * SR), len(x) // 4)
    if rise > 0:
        x[:rise] *= np.linspace(0.0, 1.0, rise)
    return normalise(x)


def normalise(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    return x / max(np.abs(x).max(), 1e-9) * 10 ** (peak_db / 20)


def seamless(x: np.ndarray, overlap_s: float) -> np.ndarray:
    """A loop: its last `overlap_s` crossfaded (equal power) into its start, then cut off."""
    n = int(overlap_s * SR)
    body = x[:len(x) - n].copy()
    ramp = np.linspace(0.0, 1.0, n)
    body[:n] = body[:n] * np.sqrt(ramp) + x[len(x) - n:] * np.sqrt(1.0 - ramp)
    return normalise(body)


def mix(*parts: tuple) -> np.ndarray:
    """(signal, gain, offset s) parts summed into one."""
    length = max(len(p[0]) + int(p[2] * SR) for p in parts)
    out = np.zeros(length)
    for signal, gain, offset in parts:
        at = int(offset * SR)
        out[at:at + len(signal)] += signal * gain
    return out


# ── synthesis ────────────────────────────────────────────────────────────────

def times(d: float) -> np.ndarray:
    return np.arange(int(round(d * SR))) / SR


def osc(freq, d: float, kind: str = "square", duty: float = 0.5) -> np.ndarray:
    """An oscillator at `freq` Hz (a number, or one per sample)."""
    n = int(round(d * SR))
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, float)[:n]
    phase = np.cumsum(f) / SR
    frac = phase % 1.0
    if kind == "square":
        return np.where(frac < duty, 1.0, -1.0)
    if kind == "saw":
        return 2.0 * frac - 1.0
    if kind == "tri":
        return 4.0 * np.abs(frac - 0.5) - 1.0
    return np.sin(2.0 * np.pi * phase)


def noise(d: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(round(d * SR)))


def sweep(f0: float, f1: float, d: float, curve: float = 1.0) -> np.ndarray:
    """f0 to f1 Hz over d seconds, exponentially; curve > 1 holds f0 longer."""
    t = times(d) / d
    return f0 * (f1 / f0) ** (t ** curve)


def decay(d: float, tau: float, attack: float = 0.002) -> np.ndarray:
    e = np.exp(-times(d) / tau)
    a = min(int(attack * SR), len(e))
    e[:a] *= np.linspace(0.0, 1.0, a)
    return e


def lowpass(x: np.ndarray, cutoff: float, taps: int = 101) -> np.ndarray:
    """A windowed-sinc low-pass at a fixed cutoff (Hz)."""
    k = np.arange(taps) - (taps - 1) / 2
    h = np.sinc(2 * cutoff / SR * k) * np.hamming(taps)
    return np.convolve(x, h / h.sum(), mode="same")


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def sweep_lowpass(x: np.ndarray, cutoff: np.ndarray) -> np.ndarray:
    """A one-pole low-pass whose cutoff moves (one per sample): for whooshes."""
    a = 1.0 - np.exp(-2.0 * np.pi * np.asarray(cutoff, float) / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def crush(x: np.ndarray, bits: int) -> np.ndarray:
    step = 2.0 ** (bits - 1)
    return np.round(x * step) / step


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def notes(seq: list, kind: str = "square", duty: float = 0.5, tau: float = 0.08, vibrato: float = 0.0) -> np.ndarray:
    """(midi, seconds) one after another; the last one rings, with `vibrato` (semitones)."""
    parts = []
    for i, (midi, d) in enumerate(seq):
        last = i == len(seq) - 1
        f = np.full(int(round(d * SR)), hz(midi))
        if last and vibrato > 0:
            t = times(d)
            f = f * 2 ** (vibrato * np.sin(2 * np.pi * 6.0 * t) * np.minimum(t / 0.15, 1.0) / 12)
        parts.append(osc(f, d, kind, duty) * decay(d, d * 0.6 if last else tau, 0.003))
    return np.concatenate(parts)


# ── the SFX ──────────────────────────────────────────────────────────────────

def gatling(seed: int, top: float, d: float) -> np.ndarray:
    body = osc(sweep(top, top * 0.18, d, 0.6), d, "square", 0.3) * decay(d, d * 0.28) * 0.6
    crack = highpass(noise(d, seed), 2500) * decay(d, d * 0.13) * 0.8
    return finish(crush(body + crack, 7))


def cannon(seed: int) -> np.ndarray:
    d = 0.38
    boom = osc(sweep(210, 42, d, 0.5), d, "sine") * decay(d, 0.1)
    blast = lowpass(noise(d, seed), 1400) * decay(d, 0.05) * 1.4
    snap = osc(sweep(420, 90, 0.1), 0.1, "square", 0.4) * decay(0.1, 0.02) * 0.3
    return finish(mix((boom, 1.0, 0), (blast, 1.0, 0), (snap, 1.0, 0)))


def flak(seed: int) -> np.ndarray:
    d = 0.2
    n = noise(d, seed)
    chuff = (lowpass(n, 3200) - lowpass(n, 500)) * decay(d, 0.045) * 2.0
    pop = osc(sweep(760, 240, d), d, "square", 0.35) * decay(d, 0.03) * 0.4
    return finish(chuff + pop)


def emp() -> np.ndarray:
    d = 0.55
    t = times(d)
    zap = osc(sweep(1900, 85, d, 0.7) + 70 * np.sin(2 * np.pi * 33 * t), d, "saw") * decay(d, 0.16)
    rng = np.random.default_rng(7)
    sparks = noise(d, 8) * (rng.uniform(size=len(t)) > 0.96) * decay(d, 0.22) * 0.9
    return finish(crush(zap * 0.7 + sparks, 6))


def rocket() -> np.ndarray:
    d = 0.6
    hiss = kenney("thrusterFire_001")[:int(d * SR)] * decay(d, 0.22, 0.01)
    rise = osc(sweep(180, 620, d, 0.8), d, "tri") * decay(d, 0.2, 0.01) * 0.25
    return finish(hiss + rise)


def shield_ping(seed: int) -> np.ndarray:
    d = 0.18
    f = 2300 + seed * 170
    ring = osc(sweep(f, f * 0.7, d), d, "sine") * decay(d, 0.045)
    over = osc(sweep(f * 1.5, f, d), d, "sine") * decay(d, 0.03) * 0.5
    fizz = highpass(noise(d, seed), 5000) * decay(d, 0.01) * 0.3
    return finish(ring + over + fizz)


def shot_down() -> np.ndarray:
    d = 0.14
    pop = osc(sweep(900, 1900, d), d, "square", 0.25) * decay(d, 0.035)
    return finish(pop + highpass(noise(d, 3), 3000) * decay(d, 0.012) * 0.6)


def launch() -> np.ndarray:
    d = 2.3
    t = times(d)
    swell = np.minimum(t / 1.5, 1.0) ** 1.5 * np.where(t > 1.8, np.exp(-(t - 1.8) / 0.25), 1.0)
    whoosh = sweep_lowpass(noise(d, 21), sweep(300, 5200, d, 0.9)) * swell * 2.2
    rumble = lowpass(noise(d, 22), 220) * np.minimum(t / 0.3, 1.0) * np.exp(-t / 1.6) * 3.0
    hum = osc(sweep(42, 96, d, 0.8), d, "saw") * swell * 0.25
    roar = kenney("thrusterFire_003")[:len(t)] * swell * 0.8
    return finish(whoosh + rumble + lowpass(hum, 600) + roar, fade_ms=80)


def pod_eject() -> np.ndarray:
    d = 0.22
    pop = highpass(noise(d, 31), 900) * decay(d, 0.035) * 1.2
    thump = osc(sweep(130, 48, d), d, "sine") * decay(d, 0.06)
    burn_d = 1.3
    t = times(burn_d)
    burn = sweep_lowpass(noise(burn_d, 32), sweep(2600, 700, burn_d)) * np.minimum(t / 0.05, 1.0) * np.exp(-t / 0.5) * 1.6
    whistle = osc(sweep(900, 520, burn_d), burn_d, "tri") * np.exp(-t / 0.35) * 0.15
    return finish(mix((pop + thump, 1.0, 0.0), (burn + whistle, 0.8, 0.06)), fade_ms=60)


def bell(midi: float, d: float) -> np.ndarray:
    f = hz(midi)
    return (osc(f, d, "sine") * decay(d, d * 0.35) + osc(f * 2.76, d, "sine") * decay(d, d * 0.12) * 0.4
            + osc(f * 5.4, d, "sine") * decay(d, d * 0.05) * 0.2)


SFX = {
    # weapons (fire.<weapon id>)
    "synth/fire_gatling_1": lambda: gatling(1, 1100, 0.09),
    "synth/fire_gatling_2": lambda: gatling(2, 1040, 0.09),
    "synth/fire_gatling_3": lambda: gatling(3, 1180, 0.09),
    "synth/fire_multi_1": lambda: gatling(4, 1500, 0.06),
    "synth/fire_multi_2": lambda: gatling(5, 1420, 0.06),
    "synth/fire_cannon_1": lambda: cannon(6),
    "synth/fire_cannon_2": lambda: cannon(7),
    "synth/fire_flak_1": lambda: flak(8),
    "synth/fire_flak_2": lambda: flak(9),
    "synth/fire_emp": emp,
    "synth/fire_rocket": rocket,
    "kenney/mine_drop": lambda: finish(kenney("drop_002")),
    "kenney/beam_loop": lambda: seamless(kenney("forceField_000"), 0.15),
    # hits and blasts
    "kenney/hit_hull_1": lambda: finish(kenney("impactMetal_light_000")),
    "kenney/hit_hull_2": lambda: finish(kenney("impactMetal_light_001")),
    "kenney/hit_hull_3": lambda: finish(kenney("impactMetal_light_002")),
    "kenney/hit_hull_4": lambda: finish(kenney("impactMetal_light_004")),
    "synth/hit_shield_1": lambda: shield_ping(0),
    "synth/hit_shield_2": lambda: shield_ping(1),
    "synth/hit_shield_3": lambda: shield_ping(2),
    "kenney/tile_break_1": lambda: finish(kenney("impactPlate_heavy_001")),
    "kenney/tile_break_2": lambda: finish(kenney("impactPlate_heavy_003")),
    "kenney/boom_small_1": lambda: finish(kenney("explosionCrunch_000")),
    "kenney/boom_small_2": lambda: finish(kenney("explosionCrunch_002")),
    "kenney/boom_big": lambda: finish(mix((kenney("lowFrequency_explosion_000"), 1.0, 0.0),
                                          (kenney("explosionCrunch_004"), 0.7, 0.0)), fade_ms=120),
    "kenney/boom_blast": lambda: finish(kenney("explosionCrunch_001")[:int(0.9 * SR)], fade_ms=200),
    "synth/shot_down": shot_down,
    # pickups and the run
    "synth/pickup_loot": lambda: finish(notes([(83, 0.05), (88, 0.12)], "square", 0.25)),
    "synth/pickup_part": lambda: finish(notes([(72, 0.05), (76, 0.05), (79, 0.05), (84, 0.2)], "square", 0.25)),
    "synth/power_up": lambda: finish(notes([(60 + s, 0.045) for s in (0, 4, 7, 12, 16, 19, 24)] + [(84, 0.4)],
                                           "square", 0.25, vibrato=0.4)),
    "synth/power_down": lambda: finish(notes([(79, 0.11), (76, 0.11), (72, 0.25)], "square", 0.5)),
    "synth/wave_start": lambda: finish(mix(*[(lowpass(osc(hz(57), 0.28, "saw") + osc(hz(64), 0.28, "saw"), 1800)
                                              * decay(0.28, 0.5, 0.01), 1.0, k * 0.36) for k in range(2)]), fade_ms=40),
    "synth/wave_cleared": lambda: finish(mix((notes([(72, 0.09), (76, 0.09), (79, 0.09), (84, 0.5)], "square", 0.5,
                                                    vibrato=0.3), 1.0, 0.0),
                                             (notes([(48, 0.27), (55, 0.5)], "tri"), 0.8, 0.0))),
    "synth/run_over": lambda: finish(notes([(67, 0.2), (66, 0.2), (65, 0.2), (64, 0.8)], "square", 0.5, tau=0.15,
                                           vibrato=0.5), fade_ms=60),
    "synth/new_best": lambda: finish(mix((notes([(76, 0.06), (79, 0.06), (83, 0.06), (88, 0.6)], "square", 0.25,
                                                vibrato=0.3), 1.0, 0.0),
                                         (highpass(noise(0.8, 41), 7000) * decay(0.8, 0.25), 0.25, 0.15),
                                         (bell(76, 0.8), 0.6, 0.18))),
    "synth/gun_level_up": lambda: finish(mix((bell(79, 0.45), 1.0, 0.0), (bell(86, 0.6), 1.0, 0.12))),
    # the bay, the pod and the dock (8.1)
    "synth/launch": launch,
    "synth/pod_eject": pod_eject,
    "kenney/dock_clamp": lambda: finish(mix((kenney("impactMetal_heavy_000"), 1.0, 0.0),
                                            (kenney("impactPlate_heavy_003"), 0.8, 0.07))),
    "kenney/dock_shutter": lambda: finish(kenney("doorClose_001")),
    "kenney/engine_loop": lambda: seamless(kenney("spaceEngineSmall_000"), 0.4),
    # the UI and the hangar
    "kenney/ui_click": lambda: finish(kenney("select_001")),
    "kenney/ui_back": lambda: finish(kenney("back_002")),
    "kenney/ui_buy": lambda: finish(kenney("confirmation_001")),
    "kenney/ui_sell": lambda: finish(kenney("confirmation_003")),
    "kenney/ui_error": lambda: finish(kenney("error_004")),
    "kenney/ui_toggle": lambda: finish(kenney("toggle_002")),
    "kenney/hangar_place": lambda: finish(kenney("impactMetal_medium_001")),
    "kenney/hangar_remove": lambda: finish(kenney("minimize_007")),
}


# ── the music ────────────────────────────────────────────────────────────────

MINOR = [0, 2, 3, 5, 7, 8, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
RHYTHMS = [[2, 2, 2, 2], [3, 3, 2], [1, 1, 2, 2, 2], [4, 2, 2], [2, 1, 1, 4], [6, 2], [2, 2, 4], [3, 1, 2, 2]]


class Track:
    """One loop: `bars` of 4 beats at `bpm`, over chords given per bar as scale degrees (0-based)
    in `mode` from `root` (MIDI). `form` names each 4-bar block's melody ("A", "B", ...; "-" for
    none) and `parts` which voices play in it."""

    def __init__(self, bpm, root, mode, chords, form, parts, seed, lead_duty=0.5, swing=0.0):
        self.bpm, self.root, self.mode = bpm, root, mode
        self.chords, self.form, self.parts = chords, form, parts
        self.rng = np.random.default_rng(seed)
        self.lead_duty, self.swing = lead_duty, swing
        self.beat = 60.0 / bpm
        self.length = int(round(len(chords) * 4 * self.beat * SR))
        self.out = np.zeros((self.length, 2))

    def pitch(self, degree: int, octave: int) -> int:
        return self.root + 12 * (octave + degree // 7) + self.mode[degree % 7]

    def chord(self, bar: int) -> list:
        d = self.chords[bar]
        return [d, d + 2, d + 4]

    def add(self, at_s, signal, gain, pan=0.0):
        """Mixes `signal` in at `at_s`, wrapping past the end onto the start (a seamless loop)."""
        start = int(round(at_s * SR)) % self.length
        idx = (np.arange(len(signal)) + start) % self.length
        left, right = np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)
        np.add.at(self.out[:, 0], idx, signal * gain * left)
        np.add.at(self.out[:, 1], idx, signal * gain * right)

    def note(self, at_s, d, midi, kind, gain, pan=0.0, duty=0.5, tau=None, attack=0.004, vibrato=0.0):
        ring = d + 0.06
        f = np.full(int(round(ring * SR)), hz(midi))
        if vibrato:
            t = times(ring)
            f = f * 2 ** (vibrato * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.12) / 0.2, 0, 1) / 12)
        env = decay(ring, tau if tau else d * 3.0, attack)
        cut = int(d * SR)
        env[cut:] *= np.linspace(1.0, 0.0, len(env) - cut)
        self.add(at_s, osc(f, ring, kind, duty) * env, gain, pan)

    def bar_s(self, bar: int) -> float:
        return bar * 4 * self.beat

    def eighth_s(self, bar: int, k: int) -> float:
        return self.bar_s(bar) + k * self.beat / 2 + (self.swing * self.beat / 2 if k % 2 else 0.0)

    def drums(self, bar: int, style: str) -> None:
        kick = osc(sweep(150, 45, 0.18), 0.18, "sine") * decay(0.18, 0.06)
        snare = (highpass(noise(0.16, bar), 1200) * decay(0.16, 0.05) * 0.7
                 + osc(190, 0.16, "tri") * decay(0.16, 0.03) * 0.5)
        hat = highpass(noise(0.05, 100 + bar), 6500) * decay(0.05, 0.012)
        for k in range(8):
            at = self.eighth_s(bar, k)
            if style == "drive":
                if k % 2 == 0:
                    self.add(at, kick, 0.55)
                if k in (2, 6):
                    self.add(at, snare, 0.42)
                self.add(at, hat, 0.16 if k % 2 else 0.1, 0.3)
            elif style == "soft":
                if k in (0, 5):
                    self.add(at, kick, 0.4)
                if k in (2, 6):
                    self.add(at, snare, 0.18)
                self.add(at, hat, 0.08, -0.3)
            elif style == "pulse":
                if k == 0:
                    self.add(at, kick, 0.35)
                if k % 2:
                    self.add(at, hat, 0.06, 0.4)

    def bass(self, bar: int, style: str) -> None:
        root = self.pitch(self.chords[bar], 2)
        for k in range(8):
            at = self.eighth_s(bar, k)
            if style == "drive":
                midi = root + (12 if k in (3, 7) else 0)
                self.note(at, self.beat * 0.42, midi, "square", 0.22, duty=0.25, tau=0.12)
            elif style == "walk" and k % 2 == 0:
                fifth = self.pitch(self.chords[bar] + 4, 2)
                self.note(at, self.beat * 0.8, [root, root, fifth, root + 12][k // 2], "tri", 0.4, tau=0.4)
            elif style == "hold" and k == 0:
                self.note(at, self.beat * 3.8, root, "tri", 0.4, tau=3.0, attack=0.05)

    def arp(self, bar: int, rate: int, gain: float) -> None:
        tones = [self.pitch(d, 4) for d in self.chord(bar)]
        pattern = tones + [tones[1]]  # up and back: 1 3 5 3
        steps = 4 * rate
        for k in range(steps):
            at = self.bar_s(bar) + k * self.beat / rate
            self.note(at, self.beat / rate * 0.7, pattern[k % len(pattern)] + 12, "square", gain,
                      pan=0.5 if k % 2 else -0.5, duty=0.125, tau=0.09)

    def pad(self, bar: int) -> None:
        for i, d in enumerate(self.chord(bar)):
            midi = self.pitch(d, 3)
            for detune in (-0.08, 0.08):
                self.note(self.bar_s(bar), self.beat * 4, midi + detune, "saw", 0.05, pan=detune * 6,
                          tau=8.0, attack=0.4)

    def phrase(self, first_bar: int) -> list:
        """A 4-bar melody over the chords from `first_bar`: (bar, eighth, length in eighths, midi)."""
        out = []
        degree = self.chord(first_bar)[2] + 7
        for b in range(4):
            bar = first_bar + b
            rhythm = RHYTHMS[self.rng.integers(len(RHYTHMS))] if b < 3 else [4, 4] if self.rng.random() < 0.5 else [2, 6]
            k = 0
            for length in rhythm:
                tones = [d + 7 for d in self.chord(bar)] + [d + 14 for d in self.chord(bar)]
                if k % 4 == 0:  # on the beat: the chord tone nearest
                    degree = min(tones, key=lambda t: abs(t - degree) + self.rng.random() * 2.5)
                else:
                    degree += int(self.rng.choice([-2, -1, -1, 1, 1, 2]))
                degree = int(np.clip(degree, 7, 18))
                if self.rng.random() > 0.12 or k == 0:
                    out.append((b, k, length, self.pitch(degree, 4)))
                k += length
        return out

    def lead(self, bar: int, phrase: list, gain: float) -> None:
        for b, k, length, midi in phrase:
            at = self.eighth_s(bar + b, k)
            d = length * self.beat / 2 * 0.92
            self.note(at, d, midi, "square", gain, duty=self.lead_duty, tau=d * 1.8, vibrato=0.25 if length >= 4 else 0.0)
            self.note(at + self.beat * 0.75, d, midi, "square", gain * 0.28, pan=0.6, duty=self.lead_duty, tau=d)

    def render(self) -> np.ndarray:
        phrases = {}
        for block, name in enumerate(self.form):
            first = block * 4
            parts = self.parts[block]
            if name != "-" and name not in phrases:
                phrases[name] = self.phrase(first)
            for bar in range(first, first + 4):
                if "pad" in parts:
                    self.pad(bar)
                for style in ("drive", "walk", "hold"):
                    if "bass_" + style in parts:
                        self.bass(bar, style)
                if "arp16" in parts:
                    self.arp(bar, 4, 0.05)
                elif "arp8" in parts:
                    self.arp(bar, 2, 0.06)
                for style in ("drive", "soft", "pulse"):
                    if "drums_" + style in parts:
                        self.drums(bar, style)
            if name != "-":
                self.lead(first, phrases[name], 0.11)
        mixed = np.tanh(self.out * 1.3) / np.tanh(1.3)
        return mixed / np.abs(mixed).max() * 10 ** (-1.0 / 20)


def menu() -> np.ndarray:
    # Owner, 2026-10-31: nobody lingers on the menu, so it hits from the first beat: fast, full
    # drums and the hook straight away, no build-up.
    i, iii, iv, v, vi, vii = 0, 2, 3, 4, 5, 6
    block = [i, vi, iii, vii]
    full = {"bass_drive", "arp16", "drums_drive"}
    return Track(140, 57, MINOR, block * 2 + [iv, vi, vii, v] + block,
                 ["A", "A", "B", "A"],
                 [full, full, full | {"pad"}, full], seed=140, lead_duty=0.25).render()


def hangar() -> np.ndarray:
    i, iv, vi, vii, v = 0, 3, 5, 6, 4
    block = [i, iv, i, iv]
    return Track(100, 50, DORIAN, block * 2 + [vi, vii, i, i] + block + block + [vi, vii, v, v] + block * 2,
                 ["-", "A", "B", "A", "-", "B", "A", "-"],
                 [{"bass_walk", "arp8", "drums_pulse"}, {"bass_walk", "arp8", "drums_soft"},
                  {"pad", "bass_walk", "drums_soft"}, {"bass_walk", "arp8", "drums_soft"},
                  {"pad", "bass_hold", "arp16"}, {"pad", "bass_walk", "drums_soft"},
                  {"bass_walk", "arp8", "drums_soft"}, {"bass_walk", "arp8", "drums_pulse"}],
                 seed=100, lead_duty=0.25, swing=0.18).render()


def combat() -> np.ndarray:
    i, iii, iv, v, vi, vii = 0, 2, 3, 4, 5, 6
    a = [i, i, vi, vii]
    b = [iv, vi, vii, v]
    return Track(150, 52, MINOR, a * 2 + b + a + [vi, vii, i, i] + b + a * 2,
                 ["-", "A", "B", "A", "C", "B", "A", "-"],
                 [{"bass_drive", "arp16", "drums_pulse"}, {"bass_drive", "arp16", "drums_drive"},
                  {"bass_drive", "pad", "drums_drive"}, {"bass_drive", "arp16", "drums_drive"},
                  {"bass_drive", "pad", "arp8", "drums_soft"}, {"bass_drive", "pad", "drums_drive"},
                  {"bass_drive", "arp16", "drums_drive"}, {"bass_drive", "arp16", "drums_drive"}],
                 seed=150, lead_duty=0.5).render()


MUSIC = {"music/menu": menu, "music/hangar": hangar, "music/combat": combat}


def main() -> int:
    only = sys.argv[1:]
    wanted = lambda name: not only or any(pathlib.PurePath(name).name.startswith(p) for p in only)
    for name, make in SFX.items():
        if wanted(name):
            x = make()
            write_wav(OUT / (name + ".wav"), x)
            print(f"{name}.wav  {len(x) / SR:.2f} s")
    for name, make in MUSIC.items():
        if wanted(name):
            given = MUSIC_SRC / (pathlib.PurePath(name).name + ".wav")
            if given.exists():  # a track from the A.12 prompts
                x = read_wav(given)
                x = np.stack([seamless(x[:, c], 1.0) for c in range(2)], axis=1)
            else:
                x = make()
            write_ogg(OUT / (name + ".ogg"), x)
            print(f"{name}.ogg  {len(x) / SR:.1f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
