# EQUAL — Equivariant q-Space Operators with Laplace-Measure Latents

Reference implementation for *"EQUAL: Equivariant q-Space Operators With
Laplace-Measure Latents for Acquisition-Universal Diffusion MRI"*.

EQUAL reads the raw, unordered measurements of a voxel neighbourhood — any
number of gradient directions, any b-values, any b-tensor shapes, any voxel
spacing — and returns, per voxel, a probability measure over diffusion tensors
whose Laplace transform is the predicted signal. It replaces interpolation with
quadrature over the acquired directions, replaces the one-hot shell token with a
continuous b-tensor descriptor, and is exactly equivariant to the joint rotation
of image space and q-space.

> ### Read this first
>
> **The quantitative results in the manuscript's Sections VIII–IX 
> measured.**  This repository stores them
> labelled as such, marks them in every generated table, and fails its own build
> gate while they remain. Nothing here reproduces or supports those numbers.
>
> What *is* established here are the structural guarantees, which hold for every
> value of the parameters and are verified by the test suite: exact symmetry
> (Theorem 1), physical validity of every synthesized signal (Theorem 4), the
> quadrature construction (Theorems 2, 3(i)), the identifiability rule
> (Theorem 5) and the extrapolation bound (Theorem 6).
>
> See [`docs/AUDIT_STATUS.md`](docs/AUDIT_STATUS.md) for what this closes and
> what it does not.

---

## Install

```bash
git clone <this repo> && cd equal-dmri
pip install -e ".[dev]"          # numpy, scipy, torch, pyyaml, pytest
```

Python ≥ 3.10. CPU is enough for the tests and the smoke runs below.

## Quick start

```bash
make test                        # 83 tests: theorems, components, audit compliance
make audit                       # the build gate (exits non-zero on the 2 findings)

python scripts/init_results.py   # build the labelled result store
python scripts/make_splits.py    # subject-level manifests with an overlap check
python scripts/build_tables.py   # regenerate every table from the store

python scripts/train.py --steps 50          # trains on in-silico fields
python scripts/evaluate.py --fields 8       # structural checks + metrics
```

`train.py` and `evaluate.py` run end-to-end with no download: they generate
in-silico fields from the signal model (2) and noise model (3). Point `--data`
at a prepared directory to use real sources.

## What the model is

```
F_Θ  =  K_ψ  ∘  B_θ  ∘  Q_φ                                        (11)
        decoder  backbone  lifting
```

**`Q_φ` — quadrature-weighted lifting** (`src/equal/lifting.py`). For each shell
it solves the minimum-norm nonnegative quadrature problem (12) for the
directions actually acquired, and uses the largest degree `L_p` those directions
support (13). Sums over measurements then approximate integrals over the sphere,
with an error Theorem 2 bounds. A continuous descriptor (14) of `(b, bΔ)`
replaces the one-hot shell token, so an unseen b-value and an unseen encoding
shape are points of the same input space rather than absent symbols.

**`B_θ` — jointly equivariant backbone** (`src/equal/backbone.py`). The patch is
a point cloud of voxel centres **in millimetres**, so the network sees voxel
size rather than absorbing it into a lattice. Messages (18) are conjugated into
the edge frame and back by Wigner blocks, with the inner map reduced to SO(2).
The symmetry is the *joint* action of SE(3) on image and q-space — the
transformation a rigid motion of the head actually induces, not the larger
product group.

**`K_ψ` — Laplace-measure decoder** (`src/equal/decoder.py`). Returns one
free-water atom and `K` tissue atoms (21); the predicted signal is their Laplace
transform (24), a convex combination of exponentials with nonnegative rates. **No
setting of the parameters can produce a signal that rises with b or exceeds the
unweighted signal.** Every readout — free-water fraction, mean diffusivity, μFA,
FOD — is a functional of that one measure.

Alongside the model, a rule that reads **only the protocol** (10) states which
readouts the data determine. It has no trainable parameters and needs no image,
so it can be run on a planned protocol before any subject is scanned.

## Verified properties

Numbers below are representative values from one run on CPU, float32 unless
noted; they vary in the last digit with the random rotations drawn. The test
suite asserts the *bound* in each case, not the exact value.

| Property | Equation | Measured |
| --- | --- | --- |
| Real SH transform by Wigner blocks | (4) | 1e-12 (float64) |
| Quadrature rule is rotation-invariant | (12) | 4e-15 (float64) |
| Rule exact to its degree, weights ≥ 0, Σw = 4π | (12), (13) | 1e-15 |
| `U_m` intertwines `D_2(R)` with conjugation | (23) | 2.4e-15 |
| **Joint rotation equivariance of `F_Θ`** | (8), (38) | **5.5e-06** |
| Permutation invariance | (8) | 6e-08 |
| Sign-flip invariance `g → −g` | (8) | exactly 0 |
| **Violation rate of (39)** | Thm 4 | **0.0000 %** |
| μFA = 1 for sticks, 0 for isotropic | (26) | 1e-6 |
| Thm 6(ii) crossing points vs. manuscript | (35) | 3.438 / 4.901 / 7.005 vs. 3.4 / 4.9 / 7.0 |
| Table XVII Wilson intervals from their counts | — | all four reproduce exactly |

A control test confirms the equivariance result is not trivial: the FOD changes
substantially under rotation, so the model is equivariant, not invariant.

## Repository layout

```
src/equal/
  sh.py              real even SH, Wigner matrices (4)
  sh_torch.py        the same basis, differentiable, fitted to sh.py
  quadrature.py      (12), (13) — the min-norm nonnegative rule
  signal_model.py    (1), (2), (3) — b-tensors, Laplace transform, Rician noise
  equivariance.py    steerable layout, SO(2) map, gated nonlinearity
  lifting.py         (14)–(17)
  backbone.py        (18)–(20)
  decoder.py         (21)–(24)
  readouts.py        (25)–(27)
  losses.py          (28)–(32)
  masking.py         the masking distribution of Section IV-F
  model.py           (6), (11) — the composed operator
  identifiability.py (10), Section IV-G — protocol-only, no parameters
  theory.py          (35), Theorem 2 rate fitting
  metrics.py         (36)–(39)
  stats.py           Section VI-D statistical protocol
  results.py         the provenance-labelled result store
  data/              protocols, in-silico generator, split manifests
  baselines/         model-based baselines of Section VI-B(a)
audit/audit.py       the build gate
docs/                equation-to-code map, audit status, provenance, reproducibility
tests/               83 tests, one class per theorem
```

## Documentation

- [`docs/EQUATION_TO_CODE.md`](docs/EQUATION_TO_CODE.md) — every equation, its
  code and its test; three convention notes; two findings.
- [`docs/AUDIT_STATUS.md`](docs/AUDIT_STATUS.md) — what is closed, what is not.
- [`docs/DATA_PROVENANCE.md`](docs/DATA_PROVENANCE.md) — sources, licences,
  and how values are labelled.
- [`docs/REPRODUCIBILITY.md`](docs/REPRODUCIBILITY.md) — the release checklist.
- [`docs/TABLES.md`](docs/TABLES.md) — .

## Two findings about the manuscript

The build gate fails on two internal inconsistencies this implementation
surfaced. Both are the class the audit already caught once — values typed rather
than computed.

1. **Table XIV's Theorem 6(ii) bound row does not follow from (35).** The
   formula is confirmed by the crossing points quoted twice in the manuscript,
   but the row's values are not what it gives. The qualitative claim survives;
   the stated slack changes.
2. **Table XI names PIGMENT as the best applicable baseline on CDMD** and reports
   22.1 %. SHARD is better on CDMD, and Table X reports 20.8 % for the same
   comparison. The abstract carries 22.1 %.

Both are detailed in [`docs/EQUATION_TO_CODE.md`](docs/EQUATION_TO_CODE.md#findings).

## Data

All eight sources are public; none is redistributed here. See
[`docs/DATA_PROVENANCE.md`](docs/DATA_PROVENANCE.md) for access and licences.
Use of HCP data requires the acknowledgment reproduced there.

## Licence

MIT for the code. The data sources carry their own terms.
