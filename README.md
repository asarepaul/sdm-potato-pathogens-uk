# Evaluation design and the apparent skill of species distribution models for potato pathogens

Code and results for a sole-author methods and negative-result paper: *How evaluation design shapes the apparent skill of species distribution models for potato pathogens* (P. K. Asare). Preprint DOI: TODO after posting. Archive DOI: TODO after the Zenodo release.

## What the paper found

Models for *Fusarium sambucinum* and *Phytophthora infestans* were fitted from GBIF records and tested under four designs: random or spatial block cross-validation, each with a target-group or a minimum convex polygon (MCP) background. Only random folds with an MCP background gave TSS above 0.5 (best 0.62). Spatial blocks gave TSS between 0.16 and 0.33. In 120 further spatial-block fits no model reached 0.5, so no ensemble was built and nothing was projected. *Alternaria solani* was not modelled (28 thinned records, below the minimum of 30). Every figure in the paper comes from the files in `results/`.

## Where things are

```
configuration_B/
  00_download_data.R          downloads GBIF records and WorldClim 2.1 (needs a free GBIF account)
  sdm_corrected_workflow.R    cleaning, VIF screen, models, four evaluation designs
  01_robustness.R             3 block-size caps x 5 seeds x 2 species x 4 algorithms = 120 fits
results/                      the output tables the paper cites (see below)
docs/                         data findings, data sources, notes on the first manuscript
R/                            scripts from the earlier design; not used for the paper
```

`results/primary_outputs/` holds the record cascade (Table 1), block sizes, and cross-validated AUC and TSS for the four designs (Table 2), plus `predictors_retained.txt`. `results/name_rule_sensitivity/` holds the stricter and broader *Fusarium* name-rule runs. `results/robustness/` holds the 120 fits, the script that makes them and the R session info.

## Data

| Input | Source | Licence |
|---|---|---|
| Pathogen records, Europe (1,209) | GBIF download, doi:10.15468/dl.pygjuu | CC BY-NC 4.0 |
| Target-group records (17,310) | GBIF download, doi:10.15468/dl.up9rsy | CC BY-NC 4.0 |
| UK records (417) | GBIF download, doi:10.15468/dl.y7jfj9 | CC BY-NC 4.0 |
| Climate | WorldClim 2.1, 19 bioclimatic variables, 2.5 arc-minutes, 1970 to 2000 (Fick and Hijmans 2017) | see worldclim.org |

Raw downloads and climate rasters are not committed. `00_download_data.R` rebuilds them. The GBIF zip files are kept by the author.

## Reproduce

1. Open R with the working directory set to `configuration_B/`.
2. Run `00_download_data.R` (set `GBIF_USER`, `GBIF_PWD` and `GBIF_EMAIL` first).
3. Set the switches in the DECISIONS block of `sdm_corrected_workflow.R` (`OCC_SET`, `CV_TYPE`, `BG_TYPE`) and run it. The primary design is `OCC_SET = "primary"`, `CV_TYPE = "spatial"`, `BG_TYPE = "target_group"`. It writes `outputs/`.
4. Run `01_robustness.R` for the 120 fits. It writes `outputs_robustness/`.

Packages: terra, sf, dplyr, geodata, rgbif, CoordinateCleaner, blockCV, randomForest, gbm, mgcv, predicts, ecospat, pROC, ggplot2, lwgeom, usdm. Versions used for the robustness run are in `results/robustness/sessionInfo_robustness.txt`. R 4.5.2 on macOS (Apple silicon).

## Known limits

- TSS thresholds are chosen on the pooled test predictions, so TSS is optimistic in every design.
- The block-size cap (1,000 km) and the minimum of 30 thinned records are judgement defaults, not published rules.
- Results can shift by about 0.09 TSS between runs; this is the noise level seen when only the name rule changed.
- Why spatial skill is low was not tested.

## Citation

See `CITATION.cff`.

## Licence

Code: MIT (see LICENSE). Occurrence data keep their CC BY-NC 4.0 licence.
