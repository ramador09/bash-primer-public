#!/usr/bin/env python3
"""Generate the synthetic scaling datasets for Notebook 17.

The data is SYNTHETIC but realistic: a strong-scaling sweep built from Amdahl's
law plus mild, *seeded* (reproducible) multiplicative noise, so the curve looks
measured rather than perfect while the underlying serial fraction stays
recoverable. Framed as a strong-scaling benchmark of a DFT geometry optimization
on Euler — physics-optional: it is just a column of cores and seconds.

Schema (kept deliberately simple so real anonymized data can be dropped in later
with NO notebook changes): `cores,walltime_s`.

Run from the repo root:  python data/scaling/generate.py

Pinned model (the answer key the notebook's `check`s rely on):
  strong scaling : Amdahl  T(N) = T1 * (s + (1-s)/N),  T1 = 7200 s,  s = 0.02
                   E(N) = 1/(1 + s(N-1))  ->  knee (largest N with E>=0.75) = 16
                   noise = uniform +/-3% on N>=2 (N=1 baseline kept exact)
  weak scaling   : T(N) = TW * (1 + c*log2(N)),  TW = 600 s,  c = 0.04 (+/-2% noise)
  RNG seed       : 1729  (fixed -> the committed CSVs are exactly reproducible)
"""
import math
import random

SEED = 1729
CORES = [1, 2, 4, 8, 16, 32, 64, 128, 256]

# --- strong scaling (Amdahl) ---
T1_STRONG = 7200.0
S_SERIAL = 0.02            # places the knee at 16 cores (E(16)=0.769, E(32)=0.617)

# --- weak scaling (constant work per core; mild communication growth) ---
TW_WEAK = 600.0
C_GROWTH = 0.04


def strong_scaling(rng):
    rows = []
    for n in CORES:
        t = T1_STRONG * (S_SERIAL + (1.0 - S_SERIAL) / n)
        if n != 1:                       # keep the 1-core baseline exact
            t *= rng.uniform(0.97, 1.03)  # +/-3% measurement jitter
        rows.append((n, round(t)))
    return rows


def weak_scaling(rng):
    rows = []
    for n in CORES:
        t = TW_WEAK * (1.0 + C_GROWTH * math.log2(n))
        if n != 1:
            t *= rng.uniform(0.98, 1.02)  # +/-2% jitter
        rows.append((n, round(t)))
    return rows


def write_csv(path, rows):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("cores,walltime_s\n")
        for n, t in rows:
            fh.write(f"{n},{t}\n")
    print(f"wrote {path}")


if __name__ == "__main__":
    import os

    here = os.path.dirname(os.path.abspath(__file__))
    rng = random.Random(SEED)
    write_csv(os.path.join(here, "strong_scaling.csv"), strong_scaling(rng))
    write_csv(os.path.join(here, "weak_scaling.csv"), weak_scaling(rng))
