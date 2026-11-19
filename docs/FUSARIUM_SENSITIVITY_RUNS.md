# Fusarium name-rule sensitivity runs

Purpose: show whether the *F. sambucinum* name rule changes the result. The primary
analysis (526 Europe records) stays the main result. These runs are reported next to
it. They are not alternatives to pick from after seeing the scores.

| Set | Rule | Europe records (before cleaning) |
|---|---|---|
| primary | sambucinum, pulicaris, cyanogena, sulphureum | 526 |
| strict | "Fusarium sambucinum" only | 338 |
| broad | primary plus names containing "roseum" | 564 |

Counts are from the earlier name audit. Check each against the new
`data/gbif/name_audit_EUROPE_<set>.csv` and `names_dropped_EUROPE_<set>.csv`.

## How to run (one set at a time, working directory `configuration_B/`)

1. In `00_download_data.R` set `NAME_SET <- "strict"` (or `"broad"`). Keep
   `EXISTING_EU_ZIP` and `EXISTING_UK_ZIP` as they are, so nothing is downloaded again.
   Run the script. It writes `data/occurrences_europe_raw_strict.csv`; the primary
   files are not touched.
2. In `sdm_corrected_workflow.R` set `OCC_SET <- "strict"` (same word) and
   `DIAGNOSTIC_ONLY <- TRUE`. Leave every other switch, `MIN_THINNED_N` (30) and the
   TSS cut-off (0.5) unchanged. Run the script. Results go to `outputs_strict/`.
3. Set both switches back to `"primary"` and `DIAGNOSTIC_ONLY <- FALSE` afterwards.
4. Repeat for `"broad"`.

## What to compare

`outputs_<set>/part2_record_cascade.csv` (records kept at each step) and
`outputs_<set>/part2_cv_performance.csv` (TSS, AUC) for *F. sambucinum* against the
primary run. Report all three. Seed `set.seed(2025)` is fixed in the script.

## Not yet verified

These changes have not been run (no R in the drafting environment). The first run may
need a fix. The "roseum" match is a substring match, so check the broad name audit for
any name that is not *Fusarium roseum* before using that set.
