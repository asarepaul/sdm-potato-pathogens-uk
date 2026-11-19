###############################################################################
# 00_download_data.R
# Rebuilds every input for the potato-pathogen SDM from public sources.
# Writes exactly the files that sdm_corrected_workflow.R (Part 2) expects:
#   data/occurrences_raw.csv            UK records: species, lon, lat (+ provenance)
#   data/occurrences_europe_raw.csv     Europe records, same columns (if ALSO_EUROPE)
#   data/gbif/name_audit.csv            every name GBIF filed under each species
#   data/target_group.csv               lon, lat (all records of the three genera in TG_REGION, bias proxy)
#   data/ (geodata cache)               WorldClim 2.1 current + CMIP6 future
#
# STATUS: run on 18 to 19 Nov 2026. GBIF download keys and DOIs are recorded in docs/DATA_SOURCES.md. 
#         Run it section by section.
#
#
# BEFORE YOU START
#  1. Create a free GBIF account (gbif.org) and set credentials once:
#       usethis::edit_r_environ()   # add the three lines below, then restart R
#       GBIF_USER="your_username"
#       GBIF_PWD="your_password"
#       GBIF_EMAIL="your_email"
#  2. Create a project folder and put this script in it. Initialise git or back
#     the folder up to two places (cloud + external drive). Do not lose this twice.
#  3. Disk: allow roughly 5 GB for climate files and disk for the target-group download (size depends on the counts printed in section 3).
###############################################################################

pkgs <- c("rgbif", "data.table", "geodata", "terra", "dplyr", "usethis")
new <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(new)) install.packages(new)
invisible(lapply(pkgs, library, character.only = TRUE))

dir.create("data/gbif", recursive = TRUE, showWarnings = FALSE)
stopifnot("Set GBIF_USER, GBIF_PWD and GBIF_EMAIL in .Renviron first" =
            nzchar(Sys.getenv("GBIF_USER")) && nzchar(Sys.getenv("GBIF_PWD")) &&
            nzchar(Sys.getenv("GBIF_EMAIL")))

# Choose how many climate models to fetch. Start with 2 to test, then use all 5.
GCMS  <- c("ACCESS-CM2", "MRI-ESM2-0")                       # test run
# GCMS <- c("ACCESS-CM2", "MRI-ESM2-0", "MIROC6", "UKESM1-0-LL", "IPSL-CM6A-LR")  # full run
SSPS  <- c("245", "585")                                     # SSP2-4.5, SSP5-8.5
TIMES <- c("2021-2040", "2041-2060", "2061-2080", "2081-2100")

# DECISIONS TO MAKE BEFORE YOU LOOK AT ANY RESULTS (write them in the Methods).
#
# (a) Europe records. UK-only GBIF data gave 203 / 192 / 22 records (Fusarium /
#     P. infestans / A. solani), far too few after thinning, and a UK-only fit
#     covers a narrow climate range. TRUE also downloads and imports Europe.
ALSO_EUROPE <- TRUE
#
# (b) Which names count as each pathogen. Records are matched on
#     scientificName / verbatimScientificName (NOT on the species column)
#     against the lists below. NULL = accept everything under that species key.
#     The UK zip, requested earlier with an older key, files F. sambucinum
#     records under the accepted name "Fusarium roseum"; the Europe zip does not.
#     Name audit of the Europe download (GBIF download 0000583, requested with
#     the current accepted key for F. sambucinum): of 564 Fusarium records, 338
#     carry "Fusarium sambucinum" as the name, 146 are filed under "pulicaris"
#     names (Gibberella, Botryosphaeria, Sphaeria, Gibbera, Nectria), 40 under
#     "cyanogena" names, 2 under "sulphureum" names and 38 under "roseum" names
#     (Fusarium roseum, Fusidium roseum). GBIF returned all of these for the
#     F. sambucinum key, which implies its current taxonomy treats them as
#     synonyms. VERIFY on the GBIF species page (Synonyms tab) and cite that
#     page and the download DOI in the Methods. "roseum" names are NOT included:
#     F. roseum was a broad historical catch-all for several Fusarium species.
#     Matching is on lower-cased scientificName + verbatimScientificName.
#     Sensitivity run (strict set, 338 records): use only "Fusarium sambucinum".
# NAME_SET picks which F. sambucinum name rule is applied. "primary" is the main
# analysis (526 Europe records). "strict" and "broad" are sensitivity analyses to
# be reported alongside it, not alternatives to choose between after seeing results.
#   primary : sambucinum + pulicaris + cyanogena + sulphureum
#   strict  : "Fusarium sambucinum" only (338 records)
#   broad   : primary + names containing "roseum" (564 records)
# The GBIF zip is reused, so no new download is needed: only this filter changes.
# Non-primary sets write files with a suffix (e.g. occurrences_europe_raw_strict.csv)
# so the primary files are never overwritten.
NAME_SET <- "primary"
stopifnot(NAME_SET %in% c("primary", "strict", "broad"))
SFX <- if (NAME_SET == "primary") "" else paste0("_", NAME_SET)
FUS_NAMES <- switch(NAME_SET,
  primary = c("Fusarium sambucinum", "pulicaris", "cyanogena", "sulphureum"),
  strict  = c("Fusarium sambucinum"),
  broad   = c("Fusarium sambucinum", "pulicaris", "cyanogena", "sulphureum", "roseum"))
NAME_RULES <- list(
  "Fusarium sambucinum"    = FUS_NAMES,
  "Phytophthora infestans" = NULL,
  "Alternaria solani"      = NULL
)
NAMES_CONFIRMED <- TRUE   # set FALSE to make the script stop after writing name_audit.csv
#
# (c) Reuse the UK download you already made on the GBIF website, instead of
#     requesting a new one. Put the zip in data/gbif/ and give its file name.
#     That download lacked the hasGeospatialIssue filter; the cleaning step in
#     sdm_corrected_workflow.R runs CoordinateCleaner on it anyway.
EXISTING_UK_ZIP <- "data/gbif/0000385-261118162104854.zip"   # NA to request a new one
# Same idea for the Europe download made by section 2b. Once it exists, point
# this at it so a re-run does not submit a second request to GBIF. Its DOI is in
# data/gbif/pathogen_europe_DOI.txt.
EXISTING_EU_ZIP <- "data/gbif/0000583-261118162104854.zip"   # NA to request a new one
#
# (d) Target-group (recorder effort) region: "UK" or "EUROPE". It must match the
#     region you fit on. Europe-wide fungi is very large; see section 3.
TG_REGION <- if (ALSO_EUROPE) "EUROPE" else "UK"
CONFIRM_BIG_DOWNLOAD <- FALSE   # TRUE once you have read the size printed in section 3

###############################################################################
# 1. UK boundary
###############################################################################
uk <- geodata::gadm("GBR", level = 1, path = "data")
print(uk$NAME_1)   # expect England, Northern Ireland, Scotland, Wales

###############################################################################
# 2. Pathogen occurrence records from GBIF
###############################################################################
sp_names <- names(NAME_RULES)

# Match each name to GBIF's accepted species. For F. sambucinum expect a
# synonym match: status SYNONYM, accepted species "Fusarium roseum".
bb <- lapply(sp_names, rgbif::name_backbone, rank = "species")
bb_tab <- dplyr::bind_rows(bb)
bb_tab$query <- sp_names
print(bb_tab[, intersect(c("query", "scientificName", "status", "matchType",
                           "usageKey", "acceptedUsageKey", "speciesKey"),
                         names(bb_tab))])   # READ THIS
write.csv(bb_tab[, intersect(c("query", "scientificName", "status", "matchType",
                               "usageKey", "acceptedUsageKey", "speciesKey"),
                             names(bb_tab))],
          "data/gbif/taxon_matches.csv", row.names = FALSE)
if (!"acceptedUsageKey" %in% names(bb_tab)) bb_tab$acceptedUsageKey <- NA
# Keys are kept as TEXT: GBIF can return letter-and-number keys such as "6K4VS",
# and a downloaded file may use a different key format from the one returned now.
keys    <- dplyr::coalesce(as.character(bb_tab$acceptedUsageKey), as.character(bb_tab$usageKey))
sp_keys <- as.character(bb_tab$speciesKey)
stopifnot("GBIF returned no speciesKey for a name" = !any(is.na(sp_keys)))
key_map <- data.frame(speciesKey = sp_keys, label = sp_names)

# Read a SIMPLE_CSV download zip into a data frame.
read_gbif_zip <- function(zipf) {
  exdir <- tempfile("gbif_"); dir.create(exdir)
  unzip(as.character(zipf), exdir = exdir)
  csv <- list.files(exdir, pattern = "\\.csv$", full.names = TRUE)[1]
  x <- data.table::fread(csv, sep = "\t", quote = "", showProgress = FALSE)
  unlink(exdir, recursive = TRUE)
  x <- as.data.frame(x)
  need <- c("speciesKey", "species", "scientificName", "verbatimScientificName",
            "decimalLongitude", "decimalLatitude", "coordinateUncertaintyInMeters",
            "year", "basisOfRecord", "datasetKey")
  for (n in setdiff(need, names(x))) x[[n]] <- NA
  x
}

# Label by GBIF species key (not by the species-name string), audit the names
# that sit under each label, then keep only the names you confirmed.
tidy_occ <- function(x, tag) {
  # Label a row if its species key matches, OR if its species / scientific name /
  # verbatim name contains the pathogen name or any name in NAME_RULES. The name
  # route is a backup for a key format that differs between the file and GBIF now.
  x <- x[!is.na(x$decimalLongitude) & !is.na(x$decimalLatitude), ]
  txt <- tolower(paste(x$species, x$scientificName, x$verbatimScientificName))
  x$label <- NA_character_
  for (i in seq_along(sp_names)) {
    lab   <- sp_names[i]
    terms <- unique(tolower(c(lab, NAME_RULES[[lab]])))
    by_key  <- as.character(x$speciesKey) == sp_keys[i]
    by_name <- Reduce(`|`, lapply(terms, function(k) grepl(k, txt, fixed = TRUE)))
    x$label[is.na(x$label) & (by_key | by_name)] <- lab
  }
  cat("\nRows in file:", nrow(x), "| labelled:", sum(!is.na(x$label)),
      "| by key only vs name only: see name_audit file\n")
  cat("First speciesKey values in the file:", paste(utils::head(unique(x$speciesKey), 5), collapse = ", "), "\n")
  x <- x[!is.na(x$label), ]
  audit <- x |>
    dplyr::count(label, scientificName, verbatimScientificName, name = "n") |>
    dplyr::arrange(label, dplyr::desc(n))
  write.csv(audit, sprintf("data/gbif/name_audit_%s%s.csv", tag, SFX), row.names = FALSE)
  cat("\nNames filed under each pathogen,", tag, "(first 25 rows):\n")
  print(utils::head(audit, 25))
  stopifnot("Edit NAME_RULES at the top, then set NAMES_CONFIRMED <- TRUE. See data/gbif/name_audit_*.csv" =
              NAMES_CONFIRMED)
  nm <- tolower(paste(x$scientificName, x$verbatimScientificName))
  ok <- rep(TRUE, nrow(x))
  for (lab in names(NAME_RULES)) {
    keep <- NAME_RULES[[lab]]
    if (is.null(keep)) next
    hit <- Reduce(`|`, lapply(tolower(keep), function(k) grepl(k, nm, fixed = TRUE)))
    ok[x$label == lab & !hit] <- FALSE
  }
  dropped <- x[!ok, ] |> dplyr::count(label, scientificName, name = "n_dropped")
  write.csv(dropped, sprintf("data/gbif/names_dropped_%s%s.csv", tag, SFX), row.names = FALSE)
  cat("Records dropped by NAME_RULES,", tag, ":", sum(!ok), "\n")
  x[ok, ] |>
    dplyr::transmute(species = label, species_gbif = species,
                     scientificName, verbatimScientificName,
                     lon = decimalLongitude, lat = decimalLatitude,
                     year, basisOfRecord, datasetKey,
                     uncertainty_m = coordinateUncertaintyInMeters)
}

summarise_occ <- function(occ) {
  print(table(occ$species))
  print(table(occ$species, occ$basisOfRecord))
  print(occ |> dplyr::group_by(species) |>
          dplyr::summarise(n = dplyr::n(),
                           unique_coords = dplyr::n_distinct(paste(lon, lat)),
                           n_since_1970 = sum(year >= 1970, na.rm = TRUE),
                           n_uncert_le_5km = sum(uncertainty_m <= 5000, na.rm = TRUE),
                           n_uncert_missing = sum(is.na(uncertainty_m)),
                           median_uncertainty_m = median(uncertainty_m, na.rm = TRUE)))
}

## 2a. UK records ---------------------------------------------------------------
if (!is.na(EXISTING_UK_ZIP) && file.exists(EXISTING_UK_ZIP)) {
  zipf <- EXISTING_UK_ZIP
  cat("Using existing UK download:", zipf, "\n",
      "Cite the DOI shown on that download's GBIF page; write it in",
      "data/gbif/pathogen_download_DOI.txt\n")
} else {
  dl <- rgbif::occ_download(
    rgbif::pred_in("taxonKey", keys),
    rgbif::pred("country", "GB"),
    rgbif::pred("hasCoordinate", TRUE),
    rgbif::pred("hasGeospatialIssue", FALSE),
    format = "SIMPLE_CSV")
  rgbif::occ_download_wait(dl)
  zipf <- rgbif::occ_download_get(dl, path = "data/gbif", overwrite = TRUE)
  meta <- rgbif::occ_download_meta(dl)
  writeLines(c(paste("key:", meta$key), paste("doi:", meta$doi),
               paste("created:", meta$created)), "data/gbif/pathogen_download_DOI.txt")
  cat("CITE THIS DOI IN THE PAPER:", meta$doi, "\n")
}
occ <- tidy_occ(read_gbif_zip(zipf), "UK")
write.csv(occ, sprintf("data/occurrences_raw%s.csv", SFX), row.names = FALSE)
summarise_occ(occ)
# If one dataset dominates a species or unique_coords is far below n, investigate
# (records_by_dataset.csv). Uncertainty and year columns are used in Part 2.
write.csv(occ |> dplyr::count(species, datasetKey, sort = TRUE),
          "data/gbif/records_by_dataset.csv", row.names = FALSE)

## 2b. Europe records -----------------------------------------------------------
# Same keys, same name rules, same columns, written to its own file.
if (ALSO_EUROPE) {
  if (!is.na(EXISTING_EU_ZIP) && file.exists(EXISTING_EU_ZIP)) {
    zip_eu <- EXISTING_EU_ZIP
    cat("Using existing Europe download:", zip_eu, "\n")
  } else {
    dl_eu <- rgbif::occ_download(
      rgbif::pred_in("taxonKey", keys),
      rgbif::pred("continent", "EUROPE"),
      rgbif::pred("hasCoordinate", TRUE),
      rgbif::pred("hasGeospatialIssue", FALSE),
      format = "SIMPLE_CSV")
    rgbif::occ_download_wait(dl_eu)
    zip_eu <- rgbif::occ_download_get(dl_eu, path = "data/gbif", overwrite = TRUE)
    meta_eu <- rgbif::occ_download_meta(dl_eu)
    writeLines(c(paste("key:", meta_eu$key), paste("doi:", meta_eu$doi)),
               "data/gbif/pathogen_europe_DOI.txt")
    cat("CITE THIS DOI TOO (Europe):", meta_eu$doi, "\n")
  }
  occ_eu <- tidy_occ(read_gbif_zip(zip_eu), "EUROPE")
  write.csv(occ_eu, sprintf("data/occurrences_europe_raw%s.csv", SFX), row.names = FALSE)
  summarise_occ(occ_eu)
}

###############################################################################
# 3. Target-group background: all records of Fusarium, Phytophthora and
#    Alternaria in the fitting region (proxy for recorder effort; must cover the
#    same region as the fit)
###############################################################################
TG_GENERA <- c("Fusarium", "Phytophthora", "Alternaria")   # all species in each genus
gb <- lapply(TG_GENERA, rgbif::name_backbone, rank = "genus")
genus_keys <- vapply(gb, function(g) {
  k <- if (!is.null(g$acceptedUsageKey)) g$acceptedUsageKey else g$usageKey
  as.character(k)
}, character(1))
print(data.frame(genus = TG_GENERA, scientificName = vapply(gb, function(g) as.character(g$scientificName), ""),
                 status = vapply(gb, function(g) as.character(g$status), ""), key = genus_keys))   # READ THIS

tg_pred <- list(rgbif::pred_in("taxonKey", genus_keys),
                if (TG_REGION == "UK") rgbif::pred("country", "GB")
                else rgbif::pred("continent", "EUROPE"),
                rgbif::pred("hasCoordinate", TRUE),
                rgbif::pred("hasGeospatialIssue", FALSE),
                rgbif::pred_gte("year", 1990))

# Size check BEFORE requesting. Read these numbers, then set
# CONFIRM_BIG_DOWNLOAD <- TRUE. (All fungi in Europe from 1990 was 28,284,306
# records, far too many, which is why the genera are used instead.)
n_by_genus <- vapply(genus_keys, function(k) {
  as.numeric(rgbif::occ_count(taxonKey = k,
                              country = if (TG_REGION == "UK") "GB" else NULL,
                              continent = if (TG_REGION == "EUROPE") "EUROPE" else NULL,
                              hasCoordinate = TRUE, year = "1990,2100"))
}, numeric(1))
names(n_by_genus) <- TG_GENERA
print(n_by_genus)
n_tg <- sum(n_by_genus)
cat("Target-group records to download (", TG_REGION, "):", n_tg, "\n")
stopifnot("Read the counts above, then set CONFIRM_BIG_DOWNLOAD <- TRUE to download the target group" =
            CONFIRM_BIG_DOWNLOAD)

dl_tg <- do.call(rgbif::occ_download, c(tg_pred, list(format = "SIMPLE_CSV")))
rgbif::occ_download_wait(dl_tg)
zip_tg <- rgbif::occ_download_get(dl_tg, path = "data/gbif", overwrite = TRUE)
writeLines(rgbif::occ_download_meta(dl_tg)$doi, "data/gbif/target_group_DOI.txt")

exdir <- "data/gbif/tg_unzipped"
unzip(as.character(zip_tg), exdir = exdir)
csv <- list.files(exdir, pattern = "\\.csv$", full.names = TRUE)[1]
tg <- data.table::fread(csv, sep = "\t", quote = "",
                        select = c("decimalLongitude", "decimalLatitude", "year"))
tg <- tg[!is.na(decimalLongitude) & !is.na(decimalLatitude)]
data.table::setnames(tg, c("decimalLongitude", "decimalLatitude"), c("lon", "lat"))
data.table::fwrite(tg[, .(lon, lat)], "data/target_group.csv")
cat("Target-group records:", nrow(tg), "(region:", TG_REGION, ")\n")
unlink(exdir, recursive = TRUE)   # free disk space

###############################################################################
# 4. Climate: WorldClim 2.1 current baseline (1970-2000), 2.5 arc-minutes
###############################################################################
bio <- geodata::worldclim_global("bio", res = 2.5, path = "data")
stopifnot(terra::nlyr(bio) == 19)
cat("Current climate layers OK:", terra::nlyr(bio), "\n")

###############################################################################
# 5. Climate: CMIP6 future bioclim (cached in data/ for the main script)
###############################################################################
grid <- expand.grid(gcm = GCMS, ssp = SSPS, time = TIMES, stringsAsFactors = FALSE)
grid$layers <- NA_integer_
for (i in seq_len(nrow(grid))) {
  cat(sprintf("[%d/%d] %s SSP%s %s\n", i, nrow(grid),
              grid$gcm[i], grid$ssp[i], grid$time[i]))
  grid$layers[i] <- tryCatch({
    r <- geodata::cmip6_world(model = grid$gcm[i], ssp = grid$ssp[i],
                              time = grid$time[i], var = "bioc",
                              res = 2.5, path = "data")
    terra::nlyr(r)
  }, error = function(e) { message("  FAILED: ", conditionMessage(e)); NA_integer_ })
}
write.csv(grid, "data/climate_download_log.csv", row.names = FALSE)
print(grid)
# Any row with layers != 19 failed. Re-run those, or swap in another GCM.
# The main script will skip nothing silently, so fix failures before Part 2.

###############################################################################
# 6. Record the environment so the run can be reproduced
###############################################################################
writeLines(capture.output(sessionInfo()), "data/sessionInfo_download.txt")
cat("\nDone. Next: run sdm_corrected_workflow.R (skip Part 1, which needed your lost rasters).\n")
