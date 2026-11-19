# Cross-validation design comparison (19 Nov 2026)

Cross-validated AUC and TSS for four algorithms (glm, gam, rf, brt), Europe fit, 7 retained predictors. Figures regenerated from `outputs/part2_cv_performance_*.csv` on 19 Nov 2026 (except the last two rows, see below). Each cell is one run with one random draw of 10,000 background points, so differences of about 0.02 to 0.03 are within noise.

| CV type | Background | Species | AUC range | TSS range | Mean TSS |
|---|---|---|---|---|---|
| random | mcp | *F. sambucinum* | 0.80 to 0.88 | 0.51 to 0.62 | 0.56 |
| random | mcp | *P. infestans* | 0.73 to 0.82 | 0.38 to 0.53 | 0.45 |
| random | target_group | *F. sambucinum* | 0.71 to 0.74 | 0.34 to 0.40 | 0.37 |
| random | target_group | *P. infestans* | 0.60 to 0.70 | 0.27 to 0.34 | 0.31 |
| spatial | mcp | *F. sambucinum* | 0.59 to 0.67 | 0.19 to 0.33 | 0.24 |
| spatial | mcp | *P. infestans* | 0.61 to 0.66 | 0.16 to 0.29 | 0.22 |
| spatial | target_group | *F. sambucinum* | not recoverable | not recoverable | 0.25 (screenshot) |
| spatial | target_group | *P. infestans* | not recoverable | not recoverable | 0.22 (screenshot) |

Provenance of the last two rows: they came from the first spatial/target-group run (seed 2025, 1,000 km blocks). That run's CSV (`part2_cv_performance.csv`) was overwritten by the final robustness run, so only the screenshot means survive and the ranges cannot be recovered. The robustness section below gives regenerated figures for the same design (1,000 km, seeds 101 to 105): mean TSS 0.23 (*F. sambucinum*) and 0.20 (*P. infestans*). Quote those, not the two screenshot means.

Notes
- "random" is 5-fold random, the closest cross-validated analogue of the original random 70/30 split. "mcp" is a background drawn inside the convex polygon of each species' own records, an approximation of the original.
- Spatial folds are 1,000 km blocks (cap). Fold test sets are unbalanced (for example 4 to 81 presences per fold for *F. sambucinum* in one run), so spatial estimates are noisy.
- The original manuscript reports an ensemble TSS of 0.83 and TSS 0.56 to 0.85 across methods. The closest corner here reaches a best single-model TSS of 0.62. The remaining gap is not explained (original used UK-only data, seven algorithms and nine variables).
- Boyce index values are unstable (-0.87 to 0.99 across all saved runs) and are not used.

## Robustness of the spatial design to block size and random seed (19 Nov 2026)

Main design (spatial blocks, target-group background), block size cap 500, 1,000 and 1,500 km, seeds 101 to 105, four algorithms: 120 model fits in all (`outputs/robustness_spatial.csv`). Figures regenerated from the CSV on 19 Nov 2026 and match the earlier screenshot values. Each cell pools 20 values (4 algorithms x 5 seeds); min and max include algorithm and seed differences.

| Species | Block cap | AUC mean (min to max) | TSS mean (min to max) |
|---|---|---|---|
| *F. sambucinum* | 500 km | 0.62 (0.51 to 0.70) | 0.24 (0.07 to 0.35) |
| *F. sambucinum* | 1,000 km | 0.62 (0.55 to 0.71) | 0.23 (0.14 to 0.35) |
| *F. sambucinum* | 1,500 km | 0.58 (0.50 to 0.65) | 0.19 (0.04 to 0.34) |
| *P. infestans* | 500 km | 0.60 (0.51 to 0.65) | 0.23 (0.13 to 0.29) |
| *P. infestans* | 1,000 km | 0.61 (0.56 to 0.65) | 0.20 (0.12 to 0.32) |
| *P. infestans* | 1,500 km | 0.55 (0.50 to 0.62) | 0.09 (0.03 to 0.20) |

- Highest TSS in any of the 120 runs: 0.35. Highest AUC: 0.71. No run reached the TSS 0.5 cut-off.
- Larger blocks gave lower scores; *P. infestans* at 1,500 km averaged near chance (AUC 0.55).
- Confirmed from `block_used_km` (console cross-tabulation, 19 Nov 2026): every one of the 120 fits used exactly its capped block size (40 fits each at 500, 1,000 and 1,500 km); the script's halving fallback was never triggered.
