# Manuscript checks

This file replaces an earlier version that missed the main problem. The fuller review is on the external drive in `back_Up_new/Publication_material/`: `Editorial_Review_SDM_Potato_Pathogens.docx`, `SDM_Revision_Package.docx` and `Manuscript_Revised_TrackedChanges.docx`. Move or recreate those here only if you are happy for them to be public.

## Main problems (from the editorial review)

1. **Table II is not suitability.** Each column sums to 1.000, and the values track country area. "England most suitable, Northern Ireland least" is probably an area effect, and Figure 1 contradicts it. The "northward shift" claim has the same source.
2. **Identical values.** *A. solani* values for the two scenarios at 2080 and 2100 match to three decimals, so the same raster may have been read twice.
3. **Performance claims contradict each other and the figures.** Abstract, results and conclusion give different AUC and TSS ranges. The ensemble TSS of 0.83 is not shown anywhere.
4. **Variable importance is claimed but never shown.** Table I looks like the set kept after the VIF step.
5. **Several references could not be verified.** Refs 12 to 19 and 30 to 32 in the original draft. Check each by DOI or remove it.
6. **Method gaps.** One climate model (MIROC6), scenario names written as RCP, random 70/30 splits, 1 km thinning on a roughly 4 km grid, no host or recorder-effort correction.

## Two configurations

- **Configuration A** (this repo, `R/`): rebuild of the original design, with the `sdm` package, seven algorithms and MIROC6. Its job is to reproduce what the first manuscript did, so the paper can report it as a sensitivity comparison.
- **Configuration B** (`configuration_B/`): corrected design with a bias-corrected background, spatial block cross-validation, several climate models and regional metrics that do not depend on area. It was written earlier and has not been run.

Run Part 1 of `sdm_corrected_workflow.R` on any surviving prediction rasters first. It checks the duplicate-scenario problem and recomputes regional metrics in hours. No such rasters were found on the drive or in Downloads.

## Before the repo goes public

- Confirm co-authors agree.
- Check the target journal's policy on posting code and data.
- Do not publish any result table until it comes from a run of Configuration B.
