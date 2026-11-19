# Findings from the first GBIF download (UK only, 417 records)

Download key 0000385-261118162104854, GBIF Backbone taxonomy, Simple CSV, CC BY-NC 4.0.
The DOI was read from a photo of the download page. Check it against the page before citing it.

## What the data showed

| Issue | Evidence | What the scripts now do |
|---|---|---|
| Name mismatch | GBIF files *F. sambucinum* under the accepted species "Fusarium roseum". The old filter `species %in% sp_names` would have kept zero Fusarium records, with no error. | Records are labelled by GBIF species key, then filtered by a name list you set (`NAME_RULES` in `configuration_B/00_download_data.R`). The script writes `data/gbif/name_audit_*.csv` and stops until `NAMES_CONFIRMED <- TRUE`. |
| Too few records | UK records: 203 Fusarium (as filed), 192 *P. infestans*, 22 *A. solani*. Unique 2.5 arc-minute cells: 118, 113, 19. Cells from 1970 onwards: 99, 49, 9. | `ALSO_EUROPE <- TRUE` downloads and imports Europe records. `FIT_REGION <- "EUROPE"` fits on Europe and projects onto the UK. A `MIN_THINNED_N` you set in advance decides which species are modelled. |
| Coarse coordinates | Median coordinate uncertainty 7,071 m, about a 10 km grid square. Most records stating uncertainty exceed 5 km. | `MAX_UNCERT_M` (default 5000) and `KEEP_NA_UNCERT` (default FALSE) filter before thinning. Counts at each step go to `outputs/part2_record_cascade.csv`. |
| Old records | 121 of the 192 *P. infestans* records predate 1970, but the climate baseline is 1970 to 2000. | `YEAR_MIN` (default 1970). |

## Decisions that are yours, to set before seeing any model result

1. Which names count as *F. sambucinum*. Name audit of the 203 UK records (name as recorded): *Fusarium sambucinum* 193, *Gibberella pulicaris* 7, *G. cyanogena* 2, *Fusarium roseum* 1. The default keeps *F. sambucinum* only. Adding the *Gibberella* names is a taxonomic claim: do it only with a source you can cite. Excluding *F. roseum* avoids the broad historical name.
2. `MIN_THINNED_N`. The script refuses to run until you set it.
3. Uncertainty cut-off, year range and the Europe bounding box.
4. Whether to keep *A. solani*. With 22 UK records it cannot be modelled on UK data. Europe data may change that. Dropping it changes the paper's scope and needs your co-authors' agreement.

## What is still open

- Europe-wide recorder effort. The target-group download for Europe is very large. The script prints the record count and stops until `CONFIRM_BIG_DOWNLOAD <- TRUE`. A GBIF SQL download that returns counts per cell would be smaller, but its syntax is untested here.
- Fitting on Europe and projecting onto the UK changes the claim from "UK models" to "models fitted on European records, projected onto the UK". The title and abstract must say so.
- None of the R scripts have been run. R is not installed where they were written.

## Configuration A (`R/`)

Unchanged for the name problem, because `R/01_download_occurrences.R` labels records by the query name, not by the returned species string. It still has no coordinate-uncertainty or year filter, since the spocc output does not carry uncertainty. Treat Configuration A as the like-for-like rebuild only, and use Configuration B for anything you intend to report.

## Europe download and name decision (18 Nov 2026)

Europe pathogen download: GBIF download 0000583 (continent EUROPE, hasCoordinate
TRUE, hasGeospatialIssue FALSE, requested with the current accepted keys). DOI is in
data/gbif/pathogen_europe_DOI.txt. 1209 records in the file.

Names filed under Fusarium sambucinum in the Europe file (564 records):

| Names | Records |
|---|---|
| "Fusarium sambucinum" | 338 |
| "pulicaris" names (Gibberella, Botryosphaeria, Sphaeria, Gibbera, Nectria) | 146 |
| "cyanogena" names | 40 |
| "sulphureum" names | 2 |
| "roseum" names (Fusarium roseum, Fusidium roseum) | 38 |

Decision (Kojo, 18 Nov 2026): include the "sambucinum", "pulicaris", "cyanogena" and
"sulphureum" names (526 records); exclude "roseum" names. Run the strict set (338
records) as a sensitivity analysis and report both.

To do before this goes in a paper: confirm on the GBIF species page for Fusarium
sambucinum (Synonyms tab) that the included names are listed as synonyms, and cite
that page and the download DOI. The inclusion rests on GBIF returning these records
for the F. sambucinum key, which I inferred, not on a taxonomic reference.

Europe counts per species after the name rule (each column counted separately):

| Species | Records | Since 1970 | Uncertainty 5 km or better | Uncertainty missing |
|---|---|---|---|---|
| F. sambucinum (strict, 338) | 338 | 280 | 181 | 16 |
| P. infestans | 549 | 226 | 222 | 132 |
| A. solani | 96 | 48 | 45 | 30 |

The F. sambucinum row is the strict set. Recount after applying the wider rule.

Target group: all fungi in Europe from 1990 is 28,284,306 records, too large. Replaced by
all records of Fusarium, Phytophthora and Alternaria in Europe from 1990. Counts to be
read from the script output before downloading.

## Modelling decisions fixed before any model was run (18 Nov 2026)

Kojo accepted the proposed defaults, with no exceptions. Write these in the Methods.

| Setting | Value |
|---|---|
| Fitting region | Europe, projected onto the UK |
| Europe box (lon/lat) | -25 to 45, 34 to 72 |
| Maximum coordinate uncertainty | 5000 m |
| Records with no uncertainty value | dropped |
| Earliest year | 1970 (records with no year dropped) |
| Minimum thinned records to model a species | 30 |
| Target group | all records of Fusarium, Phytophthora and Alternaria in Europe from 1990 (17,310 records downloaded) |

The value 30 for the minimum thinned records is a judgement, not a cited rule. Replace it
with a cited value if one is found, and state that it was fixed before the models were run.
Part 1 of sdm_corrected_workflow.R is skipped because the original prediction rasters
are lost.

## Spatial block size for cross-validation (18 Nov 2026)

First run of `configuration_B/sdm_corrected_workflow.R` on the Europe fit:

- Thinned records after filtering: *Fusarium sambucinum* 185, *Phytophthora infestans* 114, *Alternaria solani* 28. *A. solani* is below `MIN_THINNED_N = 30` and is not modelled. The threshold was fixed before any run and was not changed after seeing this count.
- `blockCV::cv_spatial_autocor()` on the seven retained predictors (bio1, bio2, bio4, bio8, bio15, bio18, bio19) returned a range of 6,811,882 m (about 6,800 km), read from the console on 18 Nov 2026. This is larger than the study region, so using it as block size gave one block and `cv_spatial()` stopped ("'k' is bigger than the number of spatial blocks: 1").
- Decision, made before any model was fitted and before any performance figure was seen: block size = min(autocorrelation range, `BLOCK_SIZE_CAP_M` = 1,000 km). If that gives fewer blocks than folds it is halved, never below `BLOCK_SIZE_MIN_M` = 250 km. Both values are judgement defaults, not from a citation. The size used per species is written to `outputs/part2_block_size.csv`.
- Consequence to report: blocks smaller than the autocorrelation range leave some spatial dependence between training and test folds, so cross-validated scores may be optimistic. A sensitivity run at other block sizes (for example 500 km and 1,500 km) is advisable before the numbers are quoted.
- Technical notes: `cv_spatial_autocor()` failed under sf's spherical geometry ("Loop 0 is not valid", located with `traceback()`), so s2 is switched off for that call only. This needs the `lwgeom` package. Blocks are built on points projected to EPSG:3035.

## First complete run, Europe fit, spatial block cross-validation (19 Nov 2026)

Numbers read from the console on 19 Nov 2026 (`outputs/part2_cv_performance.csv`, `outputs/part2_block_size.csv`). Test setting for projections was the full five-GCM set in Part 2.

- Block size used: 1,000 km for both modelled species. The autocorrelation range returned was 18,873,375 m (*F. sambucinum*) and 14,600,727 m (*P. infestans*), many times the extent of the study region, so it carries no information and the block size is set by the cap alone.
- Cross-validated performance, all algorithms: AUC 0.60 to 0.67, TSS 0.18 to 0.30. Boyce index ranged 0.23 to 0.89 with no relation to AUC or TSS.
- Every algorithm for both species is below the TSS >= 0.5 cut-off in the script, so no ensemble was formed. The projection rasters written in this run came from an empty ensemble and are INVALID. Do not use or cite them.
- The script was changed so that a species with no ensemble is not projected and is listed in `outputs/part2_no_ensemble.txt`.
- The TSS >= 0.5 cut-off matches the manuscript's own Methods, which state that TSS above 0.5 indicates good predictive capacity. The citation behind that statement has not been checked here and must be verified before it is relied on. The cut-off must not be lowered because the results are weak.

## Why the original and corrected performance figures differ (19 Nov 2026)

From the manuscript Methods: a random 70% train and 30% test split ("with all data cross validated"), pseudo-absences sampled inside a minimum convex polygon around each species' records, seven algorithms, nine non-collinear variables. Reported: ensemble TSS 0.83, TSS range 0.56 to 0.85, AUC above 0.76 (abstract and results), and AUC above 0.80 with TSS above 0.75 (conclusion); the sections disagree.

The corrected workflow differs in evaluation (1,000 km spatial blocks), background (target-group, bias-corrected), fitting region (Europe), predictors (seven after VIF) and algorithms (four). The drop to cross-validated TSS 0.18 to 0.30 cannot be attributed to any one of these without testing.

Diagnostic runs (sensitivity analyses, to be reported, not chosen between): `CV_TYPE` and `BG_TYPE` switches in `configuration_B/sdm_corrected_workflow.R`, `DIAGNOSTIC_ONLY = TRUE`. Results go to `outputs/part2_cv_performance_<cv>_<bg>.csv`. Random folds here are 5-fold random, the closest cross-validated analogue of the original 70/30 split, and the MCP background is built from each species' own records, an approximation of the original.

## Fusarium sambucinum name rule: checks made on 19 Nov 2026

Source: `data/gbif/name_audit_EUROPE.csv` and `data/occurrences_europe_raw.csv` from the Europe download (GBIF key 0000583). The 526 retained records break down by the name the data provider wrote (verbatim) and the name GBIF interpreted (scientificName):

- 337 records carry "Fusarium sambucinum" as the provider's name. Of these, 200 are interpreted by GBIF as "Fusarium roseum Link". They are kept because the provider named them *F. sambucinum*, not because of the GBIF reading.
- 140 provider names "Gibberella pulicaris", 39 "Gibberella cyanogena", plus a few under Sphaeria, Botryosphaeria, Gibbera and Nectria pulicaris or cyanogena, and 1 each "Fusarium sulphureum" and "Fusarium discolor var. sulphureum".
- 38 records whose provider name is *F. roseum* or *Fusidium roseum* are excluded by the rule.

Strict sensitivity set (provider or GBIF name is "Fusarium sambucinum" only) is 338 records, the figure used in the script comments. Broad set is 526.

Outside evidence found by web search (not GBIF, and not yet read in full): the New Zealand Organisms Register, Biota of New Zealand and the USDA National Agricultural Library thesaurus each list *Gibberella pulicaris*, *G. cyanogena* and *F. sulphureum* as synonyms of *F. sambucinum*. The latter two also list *F. roseum*; Biota of New Zealand notes that conservation of *F. sambucinum* over *F. roseum* was adopted (Gams et al. 1997, Gams 1999). Nirenberg (1995, Mycopathologia 129: 131-141) separates *F. sambucinum* sensu stricto from *F. torulosum* and *F. venenatum*, so records named *F. sambucinum* may include close relatives. Treat these as leads to read, not citations.

What this means for the rule:
- Including pulicaris, cyanogena and sulphureum names is supported by three independent synonym lists, but each source must be opened and cited.
- Excluding the 38 roseum-named records is a judgement. *F. roseum* is a listed synonym in two of those sources, yet it was historically a broad catch-all name. The effect is small (38 of 564 records) and the strict run covers it.
- Still to do by hand: open the GBIF species page for *Fusarium sambucinum*, read the Synonyms tab, and confirm each included name appears there. The GBIF API is not reachable from the analysis environment, so this was not checked against GBIF itself.
- Still to do: run the workflow on the strict 338 set and report both sets as a sensitivity analysis.

### GBIF Synonyms tab checked by hand (19 Nov 2026, species page gbif.org/taxon/6K4VS)

Read from photographs of the page. The Synonyms section lists 57 results. Seen on the first screen (the rest of the list was not photographed in full):

- Present: *Gibberella cyanogena*, *Sphaeria cyanogena*, *Gibberella pulicaris*, *Gibbera pulicaris*, *Nectria pulicaris*, *Botryosphaeria pulicaris*, *Fusarium sulphureum*, *Fusarium discolor* var. *sulphureum*.
- *Sphaeria pulicaris* Fr.: a page search found one match, which was inside the word "Botryosphaeria", so it is not listed as a separate entry. Two records carry this name (2 of 526). It is the basionym of *Gibberella pulicaris* (Fr.) Sacc. and *Botryosphaeria pulicaris* (Fr.) Ces. & De Not. (the "(Fr.)" in those names marks Fries's original *Sphaeria pulicaris*), and GBIF returned the records under the *F. sambucinum* key. Kept; the effect of dropping them is at most 2 records.
- "roseum": a page search found 6 matches. Two sit in the Type material section: *Fusarium roseum* Link (type, BPI 452843) and *Fusarium roseum* var. *matthiolae* P.Karst. (type, H). One is *Fusarium roseum* f. *cereale* (Snyder & Hansen) in the Synonyms list. The other three were not photographed. GBIF therefore treats *F. roseum* Link as part of the *F. sambucinum* concept, which agrees with the New Zealand and USDA lists above.

Consequence for the rule: the stated reason for excluding the 38 *roseum*-named records ("historical catch-all name") is not supported by anything checked so far, and the evidence found points the other way. It is a judgement, not a verified fact. The primary analysis keeps the rule fixed before any model results were seen (526 records). Report two sensitivity sets alongside it: strict (provider or GBIF name "Fusarium sambucinum" only, 338 records) and broad (all 564 Fusarium records GBIF returned for the key, including the 38 *roseum*-named). The broad set has not been built yet.
