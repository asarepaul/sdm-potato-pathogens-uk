# Fusarium name-rule sensitivity: results (19 Nov 2026)

Run by Kojo in RStudio (R 4.5.2) from `configuration_B/`, using
`00_download_data.R` (`NAME_SET`) and `sdm_corrected_workflow.R` (`OCC_SET`),
with the settings in the DECISIONS block unchanged: `FIT_REGION "EUROPE"`,
`MAX_UNCERT_M 5000`, `YEAR_MIN 1970`, `MIN_THINNED_N 30`, `BLOCK_SIZE_CAP_M 1000000`,
`CV_TYPE "spatial"`, `BG_TYPE "target_group"`, `DIAGNOSTIC_ONLY TRUE`, `set.seed(2025)`.
The same GBIF Europe download was reused for all three sets. Figures below are read
from `outputs/`, `outputs_strict/` and `outputs_broad/` (`part2_record_cascade.csv`,
`part2_cv_performance.csv`).

## Name rules

| Set | Rule | Europe records before cleaning |
|---|---|---|
| primary | sambucinum, pulicaris, cyanogena, sulphureum | 526 |
| strict | "Fusarium sambucinum" only | 338 |
| broad | primary plus names containing "roseum" | 564 |

The broad name audit listed only *Fusarium sambucinum*, *F. roseum*, *Fusidium roseum*,
*pulicaris*, *cyanogena* and *sulphureum* names. No other species entered the set.

## *F. sambucinum*: records kept at each step

| Step | primary | strict | broad |
|---|---|---|---|
| raw | 526 | 338 | 564 |
| one record per grid cell (final) | 185 | 131 | 187 |

All three are above `MIN_THINNED_N` (30). Intermediate steps are in each
`part2_record_cascade.csv`.

## Spatial cross-validation TSS (1,000 km blocks, one run, seed 2025)

*F. sambucinum*

| Set | glm | gam | rf | brt | mean | best |
|---|---|---|---|---|---|---|
| primary | 0.276 | 0.298 | 0.229 | 0.179 | 0.246 | 0.298 |
| strict | 0.285 | 0.296 | 0.256 | 0.160 | 0.250 | 0.296 |
| broad | 0.276 | 0.301 | 0.227 | 0.176 | 0.245 | 0.301 |

*P. infestans* (same 549 records and 114 thinned records in all three runs)

| Set | glm | gam | rf | brt | mean | best |
|---|---|---|---|---|---|---|
| primary | 0.274 | 0.231 | 0.205 | 0.190 | 0.225 | 0.274 |
| strict | 0.292 | 0.252 | 0.227 | 0.168 | 0.235 | 0.292 |
| broad | 0.216 | 0.138 | 0.224 | 0.222 | 0.200 | 0.224 |

*A. solani* has 28 thinned records in every run and is not modelled.

## What this shows

1. No method reached the pre-set TSS cut-off of 0.5 under any name rule. The best
   single score was 0.301. No ensemble would be retained, so nothing could be projected.
2. The *F. sambucinum* mean TSS is 0.246, 0.250 and 0.245 for the three sets. The name
   rule does not change the result.
3. *P. infestans* uses identical data in all three runs, yet its mean TSS ranges from
   0.200 to 0.235. That is run-to-run noise, because the seed is set once at the top and
   the random draws shift when the *Fusarium* records change. Differences of about
   0.03 between sets should not be interpreted.

## Limits

- One run per set, one seed. The earlier multi-seed robustness table (1,000 km, seeds
  101 to 105) remains the better estimate of spread.
- Record counts are before cleaning unless stated.
- This tests the name rule only. It does not test the spatial block size or any
  other decision, and it does not make the original manuscript figures reproducible.
