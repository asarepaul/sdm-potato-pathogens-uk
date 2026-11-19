# Manuscript revision plan (19 Nov 2026)

Decision (Kojo, 19 Nov 2026): report the corrected analysis honestly and reduce the claims to what it supports. Numbers below come from the runs described in `docs/DATA_FINDINGS.md` and `docs/CV_DESIGN_COMPARISON.md`. Nothing here has been checked against the original data, which is lost.

## Claims in the first draft that the corrected analysis does not support

| Draft claim | Why it cannot stay |
|---|---|
| Ensemble AUC above 0.76 and TSS above 0.56 (abstract); AUC above 0.80 and TSS above 0.75 (conclusion); ensemble TSS 0.83 (results) | The three sections disagree. Under spatial blocks, cross-validated TSS was 0.16 to 0.33 and AUC 0.59 to 0.67 for every algorithm. Under random folds and a polygon background, the closest match to the original, the best single model reached TSS 0.62. The 0.83 is not reproduced. |
| "The models were able to perform very well" | Not supported by any spatially blocked result. |
| England is most suitable; northward shift towards Scotland and Northern Ireland | Already flagged: Table II tracks country area. Also, no model passed the TSS 0.5 cut-off under the main design, so no valid projection exists. |
| Precipitation of the driest quarter and the warmest quarter are the most important predictors | Variable importance was never shown. Table I appears to list the variables kept after the VIF step. |
| *A. solani* modelled alongside the other two | 28 thinned records after filtering, below the pre-set minimum of 30. Not modelled. |

## What the corrected analysis can support

- A reproducible record pipeline (GBIF download DOIs, name audit, filtering cascade, thinning) for *F. sambucinum* (185 thinned records in the Europe fit) and *P. infestans* (114).
- A comparison of four evaluation designs showing how much the reported performance depends on the test design (see `docs/CV_DESIGN_COMPARISON.md`).
- The statement that, tested on regions the model has not seen, climate alone discriminates these two pathogens' records only weakly, and that this is a limit of the data and predictors, not only of the method.

## Suggested direction for the text (for Kojo to accept or change)

Reframe the paper from "climate risk maps for 2100" to a study of whether climate-only SDMs of potato pathogen records hold up under spatially independent testing, with future projections removed or moved to an explicitly exploratory supplement with no policy claims. Whether to keep any projection at all is Kojo's decision with the co-authors. If any is kept, the cut-off that admits a model must be justified and cited before the maps are made, not set after seeing the maps.

## Draft replacement text

Edit freely. Every figure comes from the runs above. Items in square brackets are not yet known or verified and must be filled or removed before use.

**Methods, model evaluation.** We evaluated models with five-fold cross-validation. Folds were either random or spatial blocks of up to 1,000 km, and the background was either a minimum convex polygon around each species' records or a target-group background drawn from records of the genera *Fusarium*, *Phytophthora* and *Alternaria* in Europe. The block size cap and the minimum of 30 thinned records per species were set before any model was fitted. [Block-size justification and citation to be added after the source is opened and read.]

**Results, model performance.** Performance depended mostly on how models were tested. With random folds and a polygon background, TSS ranged from 0.38 to 0.62 across algorithms and species. With spatial blocks, TSS ranged from 0.16 to 0.33 whichever background was used, and AUC from 0.59 to 0.67. No algorithm reached a TSS of 0.5 under spatial blocks. *Alternaria solani* had 28 thinned records and was not modelled.

**Limitations.** Under spatial blocks, climate alone separated presence records from background poorly. Possible reasons are that these pathogens depend on potato cultivation, storage and management that the predictors do not describe, and that GBIF records reflect where people look. We did not test either explanation. Spatial block folds were unbalanced (for example between 4 and 81 test presences per fold for *F. sambucinum* in one run), and the autocorrelation range of the predictors exceeded the study region, so the block size reflects a chosen cap. Scores come from single runs with random background draws, and differences of about 0.02 to 0.03 should not be interpreted.

## Still to do before any of this is submitted

- Done (19 Nov 2026): the spatial design was run at block caps of 500, 1,000 and 1,500 km with five seeds each; see `docs/CV_DESIGN_COMPARISON.md`. Highest TSS in 120 fits was 0.35. Block size used was confirmed to equal the cap in every run.
- Verify every reference. Open each cited paper before relying on it. Unverified so far: Roberts et al. 2017 (blocked cross-validation), Wisz et al. 2008, van Proosdij et al. 2016, Zizka et al. 2019, Fick and Hijmans 2017, and refs 12 to 19 and 30 to 32 of the draft.
- Co-authors' agreement to the new framing, and the journal's policy on code and data.
- Rewrite title, abstract and conclusion to match. The current abstract and conclusion cannot stay as written.
