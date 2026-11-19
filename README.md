# Climate-only species distribution models of three UK potato pathogens: a reproducible rebuild

R code for an ensemble species distribution model (SDM) of *Fusarium sambucinum* (dry rot), *Phytophthora infestans* (late blight) and *Alternaria solani* (early blight), designed to project to the UK under CMIP6 scenarios SSP2-4.5 and SSP5-8.5. In the rebuild, no model reached the pre-set TSS cut-off of 0.5, so no projection is produced.

## Read this first

This repository supports an unpublished manuscript ("Modelling the future of plant diseases in the UK using Ensemble Species Distribution Model", November 2025). The original code and data were lost, so everything here is a rebuild.

**The rebuild does not reproduce the manuscript's headline performance (TSS 0.83).** Under spatially blocked cross-validation, no model in the corrected workflow reached TSS 0.5. Nothing in this repository should be read as supporting the manuscript's claims about future risk. The manuscript is being revised to match what the analysis can support (`docs/MANUSCRIPT_REVISION_PLAN.md`).

Every figure in this README comes from my own runs on one machine. None of the R scripts has been independently run by anyone else yet.

## What was found

Configuration B (the corrected workflow, fitted on European records and designed to project onto the UK):

- *A. solani* was not modelled: 28 records remained after thinning, below the pre-set minimum of 30.
- For the two modelled species, no spatially blocked run reached the TSS 0.5 retention cut-off. Across 120 robustness fits (block sizes 500, 1,000 and 1,500 km, five seeds), the best was TSS 0.35 and AUC 0.71. Larger blocks scored lower.
- Because no model passed the cut-off, the workflow produces no ensemble and no valid projection maps.
- Performance was much higher under random folds with a polygon background, the design closest to the first manuscript. The gap is mostly the evaluation design, not the algorithms.
- The Boyce index was unstable and should not be quoted.

Details, with the 2 x 2 comparison of cross-validation and background designs: `docs/CV_DESIGN_COMPARISON.md`. Most table figures there were regenerated from the output CSVs; two cells survive only as screenshot means (explained in that file), so quote the robustness table instead.

All thresholds and settings were fixed before any model was run and were not lowered to obtain results. They are judgement defaults, not citations, and are listed in the DECISIONS block at the top of the workflow script.

## Repository layout

```
configuration_B/
  00_download_data.R             downloads occurrences (GBIF) and climate (WorldClim 2.1, CMIP6)
  sdm_corrected_workflow.R       corrected analysis (Configuration B)
R/                               rebuild of the original design (Configuration A), for comparison only
docs/
  CV_DESIGN_COMPARISON.md        cross-validation and background design comparison
  DATA_FINDINGS.md               problems found in the data, and the settings decided
  DATA_SOURCES.md                data sources and rebuild log
  MANUSCRIPT_CHECKS.md           problems found in the first manuscript
  MANUSCRIPT_FIXES.md            fixes
  MANUSCRIPT_REVISION_PLAN.md    what the analysis can and cannot support, and a revision plan
data/                            downloaded inputs, not tracked
outputs/                         created when the workflow runs
```

The scripts in `R/` rebuild the original design (random split, convex-polygon background, seven algorithms) and have never been run. Use `configuration_B/` for the corrected analysis.

## How to reproduce Configuration B

Requirements: R, a free GBIF account, and enough free disk (the download script header estimates roughly 5 GB for climate files; check free space before the full five-model run).

1. **GBIF credentials.** In R, run `usethis::edit_r_environ()` and add `GBIF_USER`, `GBIF_PWD` and `GBIF_EMAIL`, then restart R. Credentials live only in `.Renviron`. Never put them in a script or commit them.
2. **Set the working directory** to `configuration_B/`.
3. **Download inputs.** Run `00_download_data.R` section by section. It writes the occurrence files, the target-group file and the name audit under `data/`, and caches the climate rasters. Check `data/gbif/name_audit.csv` against the GBIF Synonyms tab before accepting the name rules. At the top of the script, `GCMS` starts as a two-model test run; switch to the five-model list for the full run.
4. **Run the analysis.** Run `sdm_corrected_workflow.R`. Part 1 is skipped automatically when no earlier prediction rasters exist. Part 2 writes performance tables to `outputs/`. If every model for a species fails the TSS 0.5 cut-off, the species is listed in `outputs/part2_no_ensemble.txt` and no maps are made for it. If no species has a usable ensemble, the script stops with an explanatory message.
5. **Diagnostic runs.** The settings `CV_TYPE` ("spatial" or "random"), `BG_TYPE` ("target_group" or "mcp") and `DIAGNOSTIC_ONLY` in the DECISIONS block switch the evaluation design. With `DIAGNOSTIC_ONLY <- TRUE` the script writes the performance and block-size tables and then stops with a message saying the stop is intended. Non-default combinations write `outputs/part2_cv_performance_<cv>_<bg>.csv`.
6. **Record the environment.** After a run, save `writeLines(capture.output(sessionInfo()), "outputs/sessionInfo.txt")` with your results.

Packages: terra, sf, dplyr, geodata, rgbif, CoordinateCleaner, blockCV, randomForest, gbm, mgcv, predicts, ecospat, pROC, ggplot2, lwgeom, plus data.table and usethis for the download script. The workflow installs missing ones.

Known pitfalls:

- With sf spherical geometry (s2) on, blockCV's autocorrelation step can fail with "Loop 0 is not valid". The script turns s2 off for that call only, which needs `lwgeom`.
- The random seed is set inside the script (`set.seed(2025)`). Change it only on purpose and record the change.
- The scripts were first written without access to the data and were debugged on a real run. If you hit a new error, record the fix in `docs/DATA_FINDINGS.md`.

## Data

Raw data is not committed, because occurrence records carry their own licences and the files are large.

| Input | Source | Notes |
|---|---|---|
| Occurrence records | GBIF download | Download DOIs are in `docs/DATA_SOURCES.md`; confirm each resolves, and add access dates |
| Current climate | WorldClim 2.1, bioclimatic variables, 2.5 arc-minute | 1970 to 2000 baseline |
| Future climate | WorldClim 2.1 CMIP6, SSP2-4.5 and SSP5-8.5 | four periods, 2021 to 2100 |
| Target-group background | GBIF records of the three genera | bias proxy |

The first manuscript used the `spocc` package (GBIF, iDigBio, iNaturalist, VertNet, ALA, OBIS). This rebuild uses GBIF directly, so counts differ from the manuscript. The name rule for *F. sambucinum* (which GBIF synonyms count) is a decision recorded in `docs/DATA_FINDINGS.md` and was checked against the GBIF Synonyms tab on 19 Nov 2026, and tested with two sensitivity sets (see docs/FUSARIUM_SENSITIVITY_RESULTS.md). The name rule did not change the cross-validated TSS.


## Still open

- Whether any future projection stays in the paper. This is an author decision, and any rule for admitting a projection must be justified and cited before maps are made.
- Verification of all references in the draft.
- The target journal's policy on code and data, before this repository is made public.

## Citation

Unpublished manuscript. Author: Paul Kojo Asare.

## Licence

Code is released under the MIT licence (see `LICENSE`). The licence covers the code only. It does not cover the manuscript text, and the data keeps its original licences.

