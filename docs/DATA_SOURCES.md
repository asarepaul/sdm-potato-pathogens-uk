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

| Download | GBIF key | DOI | Records | Download date |
|---|---|---|---|---|
| Europe pathogen records | 0000583-261118162104854 | 10.15468/dl.pygjuu | 1,209 | 18 Nov 2026 |
| Target-group records | 0000617-261118162104854 | 10.15468/dl.up9rsy | 17,310 | 18 Nov 2026 |
| UK pathogen records | 0000385-261118162104854 | 10.15468/dl.y7jfj9 | 417 | 18 Nov 2026 |

Checked on 19 Nov 2026 by opening each download page on gbif.org while signed in: the key, DOI, record count and download date above are as shown on those pages. All three are licensed CC BY-NC 4.0. The query filters on the target-group download were checked on 19 Nov 2026: Fusarium, Phytophthora and Alternaria, Europe, has coordinate, no geospatial issue, year 1990 or later, 194 datasets. The filters on the other two downloads were not checked in that pass. GBIF states that each data file is eligible for deletion after 18 May 2027 unless GBIF discovers citations of the download. Cite each download as "GBIF.org (18 November 2026) GBIF Occurrence Download" followed by its DOI link.
