# Data sources and rebuild log

Fill this in as you re-download. Record the exact access date so the rebuild is reproducible.

## Occurrence records

- Source: `spocc` (GBIF, iDigBio, iNaturalist, VertNet, ALA, OBIS), per the manuscript
- Query or filters used (including whether restricted to the UK before or after download):
- Date accessed:

Counts the manuscript reports, for comparison with the rebuild:

| Species | Records before thinning | Records after thinning |
|---|---|---|
| *Fusarium sambucinum* | 528 | 167 |
| *Phytophthora infestans* | 1146 | 569 |
| *Alternaria solani* | 7887 | 355 |

Rebuild counts (fill in, and record the cleaning step where each drop happens):

| Species | Before thinning | After thinning | Notes |
|---|---|---|---|
| *Fusarium sambucinum* | | | |
| *Phytophthora infestans* | | | |
| *Alternaria solani* | | | |

## Climate rasters

- Source: WorldClim v2.1, 2.5 arc-minute
- Current period: 1970 to 2000
- Future scenario names as they appear on the WorldClim download page (record the exact label, climate model and period):
- Date accessed:

## Known differences from the original analysis

Record anything that changed, for example a database updated since the manuscript was written, a different random seed, or a package version. Keep this section honest even if it is uncomfortable.

## GBIF downloads (recorded by `00_download_data.R`, 18 to 19 Nov 2026)

| Download | GBIF key | DOI |
|---|---|---|
| Europe pathogen records | 0000583-261118162104854 | 10.15468/dl.pygjuu |
| Target-group records (three genera) | not recorded here | 10.15468/dl.up9rsy |
| UK pathogen records | 0000385 or 0000617 (not recorded here) | 10.15468/dl.y7jfj9, unverified |

DOIs for the first two were read from `data/gbif/pathogen_europe_DOI.txt` and `data/gbif/target_group_DOI.txt`. Open each DOI to confirm it resolves to the right download before citing. The UK DOI has no file in `data/gbif/` and must be confirmed in your GBIF account's download list.
