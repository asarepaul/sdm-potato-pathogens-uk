# Manuscript fix plan

Each problem from `MANUSCRIPT_CHECKS.md`, what resolves it, and who does it. Do not edit numbers in the manuscript until the rebuilt outputs exist. Every number in the paper should be copied from a file in `outputs/tables/`.

## A. Text fixes that need no new results

Apply these now. They do not change any finding.

| Where | Current wording | Replace with |
|---|---|---|
| Abstract, algorithm list | "generalised linear additive models (GLM)" | "generalised linear models (GLM)" |
| Abstract and Methods D | "boosted region trees" | "boosted regression trees" |
| Abstract, Methods C, Results, Figs 4 and 5, Table II | "RCP 245", "RCP 585" | Use the SSP names of the layers you download, for example "SSP2-4.5" and "SSP5-8.5". "RCP 245" and "RCP 585" are not valid names. Confirm against `data/processed/future_climate_source.txt`. |
| Methods C | "we included year 2050 climate projections ... treated over four future periods" | Describe only what you used: the four 20-year periods, the scenario names and the climate model. Remove "year 2050". |
| Methods D | "cross validated" | State the design once you set `replication` and `n_replicates` in `R/config.R`. |

## B. Problems the pipeline resolves

| Problem | Output that resolves it | What to do with it |
|---|---|---|
| Variable importance claims have no support (abstract, Results B, Table I) | `variable_importance.csv`, `vif_results.csv` | Report retained variables (from the VIF step) and importance (from the models) as two separate things. Rewrite Table I and the abstract sentence from the importance table. If the abstract's "driest quarter and warmest quarter" claim does not appear in the importance ranking, drop it. |
| AUC and TSS differ across abstract, results and conclusion | `evaluation_summary.csv` | Use one set of numbers everywhere, quoted from this file. |
| Northern Ireland "more suitable by 2100" | `suitability_change_vs_current.csv` | State the size of the change and say whether it is large relative to the spread between model runs. If it is small, say so in the abstract. |
| Pseudo-absence count and cross-validation design missing | `R/config.R` | Fill the SET values, then write them into Methods D. |
| 1 km thinning on a 2.5 arc-minute raster | `occurrence_cleaning_log.csv` | Either keep 1 km and add a sentence noting that several retained records can share a raster cell, or change `thin_km` to match the raster resolution and rerun. |
| *A. solani* drops from 7887 to 355 | `occurrence_cleaning_log.csv` | The log shows which step removes the records. Write that step into Methods A. |
| Presence-only sampling bias | none | Needs a decision from you and your co-authors: add a bias layer, or state it as a limitation. |

## C. Claims to soften or support

These are statements in the discussion that the models do not test.
- Reasons given for regional differences ("moderate climate", "unpredictable rainfall") are explanations, not results. Say "may reflect" or cite a source.
- Recommendations on AI platforms, digital twins and blockchain data exchange do not follow from this analysis. Reviewers are likely to ask what in the results supports them. Consider cutting them or labelling them as future work.
- Several references have incomplete details (for example an entry listed as "Anonymous" and another with a bare DOI). Check each against the source before submission.

## D. Order of work

1. Set the SET values in `R/config.R`.
2. Run scripts 00 to 05 on your machine.
3. Send me the files in `outputs/tables/` and `data/processed/*_source.txt`.
4. I rewrite the affected manuscript passages from those files and flag anything the numbers do not support.
