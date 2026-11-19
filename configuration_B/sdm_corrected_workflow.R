###############################################################################
# Corrected workflow: climatic suitability of three potato pathogens in the UK
# Pathogens: Fusarium sambucinum, Phytophthora infestans, Alternaria solani
#
# STATUS: template written without access to your data and NOT run or tested.
# Expect to adjust file paths, object names and package versions.
# Run Part 1 first (hours, not weeks). It tells you whether a real regional
# signal exists before you invest in the full re-analysis in Part 2.
###############################################################################

pkgs <- c("terra", "sf", "dplyr", "geodata", "rgbif", "CoordinateCleaner",
          "blockCV", "randomForest", "gbm", "mgcv", "predicts", "ecospat",
          "pROC", "ggplot2", "lwgeom")
new <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(new)) install.packages(new)
invisible(lapply(pkgs, library, character.only = TRUE))
set.seed(2025)

species <- c("Fusarium sambucinum", "Phytophthora infestans", "Alternaria solani")
# OCC_SET picks the occurrence file made by 00_download_data.R (its NAME_SET):
# "primary", "strict" or "broad". Non-primary runs write to outputs_<set>/ so the
# primary outputs are never overwritten. Everything else in this script is unchanged.
OCC_SET <- "primary"
stopifnot(OCC_SET %in% c("primary", "strict", "broad"))
OUT_DIR <- if (OCC_SET == "primary") "outputs" else paste0("outputs_", OCC_SET)
dir.create(OUT_DIR, showWarnings = FALSE)

###############################################################################
# DECISIONS: set these BEFORE you look at any model results, and report them.
###############################################################################
# Region used to FIT the models. "EUROPE" fits on European records and projects
# onto the UK; "UK" fits on UK records only. UK-only GBIF data gave 203 / 192 / 22
# records (Fusarium / P. infestans / A. solani) before cleaning, which is too few.
# Must match TG_REGION in 00_download_data.R.
FIT_REGION <- "EUROPE"
EUROPE_EXT <- c(xmin = -25, xmax = 45, ymin = 34, ymax = 72)   # lon/lat box; edit and justify

# Coordinate precision. WorldClim cells are ~4 km. GBIF UK records had a median
# uncertainty of about 7 km (10 km grid squares), so most are coarser than a cell.
MAX_UNCERT_M    <- 5000    # drop records with uncertainty above this (metres)
KEEP_NA_UNCERT  <- FALSE   # records with no uncertainty stated: keep (TRUE) or drop

# Time. Climate baseline is 1970-2000, so very old records do not match it.
YEAR_MIN <- 1970
YEAR_MAX <- NA             # NA = no upper limit
KEEP_NA_YEAR <- FALSE

# Minimum thinned records (one per cell) needed to model a species. A species
# below this is reported and NOT modelled. Choose it now, from the literature
# or your own justification, not after seeing results.
# 30 is a default I proposed from judgement (enough presences for spatial block
# cross-validation folds). It is NOT from a citation. Replace it with a value you
# can cite if you find a published rule, and say in the Methods that it was fixed
# before any model was run.
MIN_THINNED_N <- 30L
# Spatial block size for cross-validation. The autocorrelation range of the
# predictors over this Europe extent came out at 6,811,882 m (about 6,800 km),
# larger than the study region, which puts every point in a single block. The
# block size used is min(autocorrelation range, BLOCK_SIZE_CAP_M). If that still
# gives fewer blocks than folds, the size is halved until it works, but never
# below BLOCK_SIZE_MIN_M. Both values are judgement defaults, NOT from a citation,
# fixed before any model was run. The size actually used is written to
# outputs/part2_block_size.csv and must be reported in the Methods. Blocks smaller
# than the true autocorrelation range leave some spatial dependence between
# training and test data, so CV scores can be optimistic: say so in the limitations.
BLOCK_SIZE_CAP_M <- 1000000   # 1,000 km
BLOCK_SIZE_MIN_M <-  250000   # 250 km

# DIAGNOSTIC SWITCHES. The main analysis is CV_TYPE = "spatial" with
# BG_TYPE = "target_group". The original manuscript used a random 70/30 split and
# pseudo-absences inside a minimum convex polygon (MCP) around each species' records.
# Running the other combinations measures how much of the drop in cross-validated
# performance comes from each choice. They are sensitivity analyses to be reported,
# not alternative results to pick from. With DIAGNOSTIC_ONLY = TRUE the script writes
# the cross-validation table for that combination and stops before projection.
CV_TYPE         <- "spatial"       # "spatial" (blockCV) or "random" (5-fold random)
BG_TYPE         <- "target_group"  # "target_group" or "mcp"
DIAGNOSTIC_ONLY <- FALSE
stopifnot(CV_TYPE %in% c("spatial", "random"), BG_TYPE %in% c("target_group", "mcp"))
stopifnot("Set MIN_THINNED_N in the DECISIONS block before running" = !is.na(MIN_THINNED_N))
stopifnot(FIT_REGION %in% c("UK", "EUROPE"))

# UK country polygons (England, Scotland, Wales, Northern Ireland)
uk <- geodata::gadm("GBR", level = 1, path = "data")
uk <- terra::project(uk, "EPSG:4326")
uk$country <- uk$NAME_1

###############################################################################
# PART 1. Recompute regional metrics from your EXISTING prediction rasters
# (fixes the area artefact in Table II and checks for duplicated scenarios)
###############################################################################
# Put your existing rasters in a folder and name them like:
#   Alternaria_solani_current.tif
#   Alternaria_solani_RCP245_2040.tif   ... etc.
# Edit 'existing_dir' and the naming pattern to match what you have.
existing_dir <- "existing_predictions"
files <- list.files(existing_dir, pattern = "\\.tif$", full.names = TRUE)

# 1a. Duplicate check: are any two rasters numerically identical?
#     (your Table II shows identical A. solani values for RCP245 and RCP585
#     at 2080 and 2100)
if (length(files) > 1) {
  rs <- lapply(files, terra::rast)
  pairs <- combn(seq_along(files), 2)
  dup <- apply(pairs, 2, function(ix) {
    d <- try(terra::global(abs(rs[[ix[1]]] - rs[[ix[2]]]), "max", na.rm = TRUE)[1, 1],
             silent = TRUE)
    if (inherits(d, "try-error")) NA else d
  })
  dup_tbl <- data.frame(a = basename(files[pairs[1, ]]),
                        b = basename(files[pairs[2, ]]),
                        max_abs_diff = dup)
  print(subset(dup_tbl, !is.na(max_abs_diff) & max_abs_diff < 1e-9))  # identical pairs
}

# 1b. Regional metrics: mean suitability and % of area above a threshold.
#     tau: use the max-TSS threshold from your own models if you have it;
#     0.5 is a placeholder only.
tau <- 0.5
regional_metrics <- function(f) {
  r <- terra::rast(f)[[1]]
  out <- lapply(seq_len(nrow(uk)), function(i) {
    v <- terra::mask(terra::crop(r, uk[i]), uk[i])
    vals <- terra::values(v, na.rm = TRUE)[, 1]
    data.frame(country = uk$country[i],
               mean_suit = mean(vals),
               pct_above_tau = 100 * mean(vals >= tau),
               n_cells = length(vals))
  })
  res <- do.call(rbind, out)
  res$file <- basename(f)
  res
}
if (length(files) > 0) {
  reg <- do.call(rbind, lapply(files, regional_metrics))
  write.csv(reg, file.path(OUT_DIR, "part1_regional_metrics_existing.csv"), row.names = FALSE)
} else {
  message("Part 1 skipped: no rasters in '", existing_dir, "'. Continuing to Part 2.")
}

# 1c. Show the artefact: your Table II 'shares' versus raw area shares
a <- terra::expanse(uk, unit = "km")
print(data.frame(country = uk$country, area_share = round(a / sum(a), 3)))
# If your Table II shares match these area shares, the Table II metric
# reflects land area, not climatic suitability.

###############################################################################
# PART 2. Corrected analysis (Configuration B)
###############################################################################

## 2.1 Occurrence data: download, clean, thin to the raster grid --------------
# Run rgbif::occ_download() with your GBIF login, then cite the DOI it returns.
# Example (needs GBIF credentials set via usethis::edit_r_environ()):
#   taxon_keys <- sapply(species, function(s) rgbif::name_backbone(s)$usageKey)
#   dl <- rgbif::occ_download(rgbif::pred_in("taxonKey", taxon_keys),
#                             rgbif::pred("country", "GB"),
#                             rgbif::pred("hasCoordinate", TRUE),
#                             format = "SIMPLE_CSV")
#   # record: rgbif::occ_download_meta(dl)$doi
# Then read the downloaded file into 'occ' with columns: species, lon, lat.
occ_sfx <- if (OCC_SET == "primary") "" else paste0("_", OCC_SET)
occ_file <- if (FIT_REGION == "EUROPE") sprintf("data/occurrences_europe_raw%s.csv", occ_sfx) else sprintf("data/occurrences_raw%s.csv", occ_sfx)
occ <- read.csv(occ_file)
occ <- occ[occ$species %in% species, ]

# Record every filter step so the paper can report the cascade.
casc <- list()
log_step <- function(step, d) casc[[length(casc) + 1]] <<-
  as.data.frame(table(species = factor(d$species, levels = species)), responseName = "n") |>
  transform(step = step)
log_step("raw (name rules applied)", occ)

occ <- occ[!is.na(occ$lon) & !is.na(occ$lat), ]
log_step("has coordinates", occ)

unc_ok <- (!is.na(occ$uncertainty_m) & occ$uncertainty_m <= MAX_UNCERT_M) |
          (is.na(occ$uncertainty_m) & KEEP_NA_UNCERT)
occ <- occ[unc_ok, ]
log_step(paste0("coordinate uncertainty <= ", MAX_UNCERT_M, " m"), occ)

yr_ok <- (!is.na(occ$year) & occ$year >= YEAR_MIN & (is.na(YEAR_MAX) | occ$year <= YEAR_MAX)) |
         (is.na(occ$year) & KEEP_NA_YEAR)
occ <- occ[yr_ok, ]
log_step(paste0("year >= ", YEAR_MIN), occ)

occ <- occ |>
  CoordinateCleaner::clean_coordinates(
    lon = "lon", lat = "lat", species = "species",
    tests = c("centroids", "equal", "gbif", "institutions", "zeros", "duplicates"),
    value = "clean")
log_step("CoordinateCleaner", occ)

# Climate baseline at UK scale. WorldClim 2.1 here to stay comparable with your
# original run; swap for UKCP18 / HadUK-Grid if you can (preferred for a UK study).
bio_world <- geodata::worldclim_global("bio", res = 2.5, path = "data")
names(bio_world) <- paste0("bio", 1:19)
bio_uk <- terra::mask(terra::crop(bio_world, uk), uk)          # projection region
bio <- if (FIT_REGION == "EUROPE") {                          # fitting region
  terra::crop(bio_world, terra::ext(EUROPE_EXT["xmin"], EUROPE_EXT["xmax"],
                                    EUROPE_EXT["ymin"], EUROPE_EXT["ymax"]))
} else bio_uk

# Thin to ONE record per raster cell (not 1 km, which is finer than the grid)
thin_to_grid <- function(df, r) {
  cell <- terra::cellFromXY(r[[1]], as.matrix(df[, c("lon", "lat")]))
  df[!duplicated(cell) & !is.na(cell), ]
}
occ_list <- lapply(split(occ, occ$species), thin_to_grid, r = bio)
n_thin <- sapply(species, function(sp) if (sp %in% names(occ_list)) nrow(occ_list[[sp]]) else 0L)
casc[[length(casc) + 1]] <- data.frame(species = species, n = as.integer(n_thin),
                                       step = "one record per grid cell")
cascade <- do.call(rbind, casc)
write.csv(cascade, file.path(OUT_DIR, "part2_record_cascade.csv"), row.names = FALSE)
print(n_thin)   # report these n in the paper

too_few <- names(n_thin)[n_thin < MIN_THINNED_N]
if (length(too_few)) {
  message("NOT MODELLED (fewer than MIN_THINNED_N = ", MIN_THINNED_N, " thinned records): ",
          paste(too_few, collapse = ", "))
  writeLines(too_few, file.path(OUT_DIR, "part2_species_not_modelled.txt"))
}
species <- setdiff(species, too_few)
stopifnot("No species has enough records; see outputs/part2_record_cascade.csv" = length(species) > 0)

## 2.2 Predictors: VIF screen ---------------------------------------------------
# usdm::vifstep is the standard tool; install if needed.
if (!requireNamespace("usdm", quietly = TRUE)) install.packages("usdm")
vif_keep <- usdm::vifstep(bio, th = 10)
bio_sel <- usdm::exclude(bio, vif_keep)
print(names(bio_sel))           # report this exact set, same for all species
# The same retained variables, cropped to the UK, are what every projection uses.
bio_sel_uk <- bio_uk[[names(bio_sel)]]
# Note: on a Europe-sized raster vifstep can be slow and memory-hungry. If it
# struggles, run it on a random sample of cells (usdm::vifstep accepts a data
# frame of values) and apply the retained names to the raster.

## 2.3 Bias-corrected background (target-group) ---------------------------------
# Records of the three genera (Fusarium, Phytophthora, Alternaria) in the fitting
# region (00_download_data.R, section 3) as a proxy of recorder effort: file with
# lon, lat columns. Its region must equal FIT_REGION.
tg <- read.csv("data/target_group.csv")
effort <- terra::rasterize(terra::vect(tg, geom = c("lon", "lat"), crs = "EPSG:4326"),
                           bio_sel[[1]], fun = "count", background = 0)
effort <- terra::mask(effort, bio_sel[[1]])

# Optional host layer: potato area (Defra / SASA) resampled to bio_sel grid.
# host <- terra::resample(terra::rast("data/potato_area.tif"), bio_sel[[1]])
# bio_sel <- c(bio_sel, host)

sample_bg <- function(n = 10000) {
  w <- terra::values(effort)[, 1]
  ok <- which(!is.na(w) & w > 0)
  idx <- sample(ok, size = min(n, length(ok)), replace = TRUE, prob = w[ok])
  idx <- unique(idx)
  terra::xyFromCell(effort, idx)
}

## 2.4 Model fitting with SPATIAL block cross-validation ------------------------
algos <- c("glm", "gam", "rf", "brt")   # fewer, simpler algorithms (small n)

fit_one <- function(method, dat, preds) {
  if (method == "glm") {
    f <- as.formula(paste("pa ~", paste0("poly(", preds, ",2)", collapse = " + ")))
    glm(f, data = dat, family = binomial)
  } else if (method == "gam") {
    f <- as.formula(paste("pa ~", paste0("s(", preds, ", k = 4)", collapse = " + ")))
    mgcv::gam(f, data = dat, family = binomial, select = TRUE)
  } else if (method == "rf") {
    n1 <- sum(dat$pa == 1)   # balanced (down-sampled) forest: n1 presences, n1 background
    randomForest::randomForest(x = dat[, preds], y = factor(dat$pa, levels = c(0, 1)),
                               ntree = 500, sampsize = c(n1, n1),
                               strata = factor(dat$pa, levels = c(0, 1)))
  } else if (method == "brt") {
    gbm::gbm(pa ~ ., data = dat[, c("pa", preds)], distribution = "bernoulli",
             n.trees = 1500, interaction.depth = 3, shrinkage = 0.01,
             bag.fraction = 0.75, verbose = FALSE)
  }
}
pred_one <- function(m, method, newdat, preds) {
  if (method %in% c("glm", "gam")) as.numeric(predict(m, newdat, type = "response"))
  else if (method == "rf") predict(m, newdat[, preds], type = "prob")[, "1"]
  else gbm::predict.gbm(m, newdat, n.trees = 1500, type = "response")
}

max_tss_threshold <- function(obs, p) {
  th <- sort(unique(p))
  tss <- sapply(th, function(t) {
    sens <- mean(p[obs == 1] >= t); spec <- mean(p[obs == 0] < t)
    sens + spec - 1
  })
  c(threshold = th[which.max(tss)], tss = max(tss))
}

run_species <- function(sp) {
  pres <- occ_list[[sp]]
  if (BG_TYPE == "target_group") {
    bg <- as.data.frame(sample_bg(10000))
  } else {
    # Background inside the minimum convex polygon of this species' own records
    hull <- terra::convHull(terra::vect(cbind(pres$lon, pres$lat), crs = "EPSG:4326"))
    inhull <- terra::mask(bio_sel[[1]], hull)
    cells <- which(!is.na(terra::values(inhull)[, 1]))
    bg <- as.data.frame(terra::xyFromCell(inhull, sample(cells, min(10000, length(cells)))))
  }
  names(bg) <- c("lon", "lat")
  xy   <- rbind(data.frame(lon = pres$lon, lat = pres$lat),
                bg)
  pa   <- c(rep(1, nrow(pres)), rep(0, nrow(bg)))
  env  <- terra::extract(bio_sel, as.matrix(xy[, c("lon", "lat")]))
  dat  <- data.frame(pa = pa, env, xy)
  dat  <- dat[complete.cases(dat), ]
  preds <- names(bio_sel)

  if (CV_TYPE == "spatial") {
    # Spatial blocks sized from spatial autocorrelation of the predictors
    pts <- sf::st_as_sf(dat, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
    # cv_spatial_autocor() intersects an internal helper polygon using sf's spherical
    # engine (s2), which fails here with "Loop 0 is not valid" (found by traceback()).
    # s2 is switched off for this one call only and restored straight after.
    s2_old <- sf::sf_use_s2(FALSE)
    ac  <- tryCatch(
      blockCV::cv_spatial_autocor(r = bio_sel, num_sample = 5000, plot = FALSE),
      finally = sf::sf_use_s2(s2_old))
    # Blocks are built in an equal-area projection (EPSG:3035, ETRS89-LAEA Europe):
    # on lon/lat data blockCV uses spherical geometry, which can fail over a region
    # this large ("Loop 0 is not valid"). Row order is unchanged, so fold indices
    # still refer to the rows of `dat`. ac$range is in metres.
    pts_m <- sf::st_transform(pts, 3035)
    block_size <- min(ac$range, BLOCK_SIZE_CAP_M)
    repeat {
      cv <- tryCatch(
        blockCV::cv_spatial(x = pts_m, column = "pa", k = 5, size = block_size,
                            selection = "random", iteration = 100, progress = FALSE),
        error = function(e) e)
      if (!inherits(cv, "error")) break
      if (!grepl("bigger than the number of spatial blocks", conditionMessage(cv))) stop(cv)
      block_size <- block_size / 2
      if (block_size < BLOCK_SIZE_MIN_M)
        stop("Block size fell below BLOCK_SIZE_MIN_M for ", sp, " and there are still too ",
             "few spatial blocks for k = 5. Check the occurrence spread before changing it.")
    }
    message(sp, ": block size used = ", round(block_size / 1000), " km (autocorrelation range ",
            round(ac$range / 1000), " km, cap ", round(BLOCK_SIZE_CAP_M / 1000), " km)")
    block_info <- data.frame(species = sp, autocorr_range_m = ac$range,
                             cap_m = BLOCK_SIZE_CAP_M, block_size_used_m = block_size)
  } else {
    # Random 5-fold split, the closest cross-validated analogue of the original
    # random 70/30 design. Folds have the same format as blockCV's folds_list.
    fold_id <- sample(rep(1:5, length.out = nrow(dat)))
    cv <- list(folds_list = lapply(1:5, function(k) list(which(fold_id != k), which(fold_id == k))))
    block_info <- data.frame(species = sp, autocorr_range_m = NA_real_,
                             cap_m = NA_real_, block_size_used_m = NA_real_)
  }

  perf <- list(); cvpred <- list()
  for (m in algos) {
    p_cv <- rep(NA_real_, nrow(dat))
    for (k in seq_along(cv$folds_list)) {
      tr <- cv$folds_list[[k]][[1]]; te <- cv$folds_list[[k]][[2]]
      fit <- fit_one(m, dat[tr, ], preds)
      p_cv[te] <- pred_one(fit, m, dat[te, ], preds)
    }
    ok <- !is.na(p_cv)
    th <- max_tss_threshold(dat$pa[ok], p_cv[ok])
    auc <- as.numeric(pROC::auc(dat$pa[ok], p_cv[ok], quiet = TRUE))
    boy <- ecospat::ecospat.boyce(fit = p_cv[ok], obs = p_cv[ok][dat$pa[ok] == 1],
                                  PEplot = FALSE)$cor
    perf[[m]] <- data.frame(species = sp, method = m, AUC = auc,
                            TSS = th["tss"], threshold = th["threshold"], Boyce = boy)
    cvpred[[m]] <- p_cv
  }
  perf <- do.call(rbind, perf)
  keep <- perf$method[perf$TSS >= 0.5]            # drop weak models
  w <- perf$TSS[perf$method %in% keep]; w <- w / sum(w)
  names(w) <- keep

  # Refit retained models on all data
  final <- lapply(keep, function(m) fit_one(m, dat, preds)); names(final) <- keep
  list(species = sp, perf = perf, keep = keep, weights = w,
       final = final, preds = preds, dat = dat, block_info = block_info)
}

results <- lapply(species, run_species); names(results) <- species
perf_all <- do.call(rbind, lapply(results, `[[`, "perf"))
perf_all$cv_type <- CV_TYPE; perf_all$bg_type <- BG_TYPE
perf_file <- if (CV_TYPE == "spatial" && BG_TYPE == "target_group") {
  file.path(OUT_DIR, "part2_cv_performance.csv")
} else {
  sprintf(file.path(OUT_DIR, "part2_cv_performance_%s_%s.csv"), CV_TYPE, BG_TYPE)
}
write.csv(perf_all, perf_file, row.names = FALSE)
write.csv(do.call(rbind, lapply(results, `[[`, "block_info")),
          file.path(OUT_DIR, "part2_block_size.csv"), row.names = FALSE)
if (DIAGNOSTIC_ONLY) {
  print(perf_all)
  stop("Diagnostic run complete (this is not an error). Results: ", perf_file, call. = FALSE)
}

# A species whose models all fall below the TSS cut-off has no ensemble. Do not
# project it: an empty ensemble gives blank or zero maps that look like results.
no_ensemble <- names(results)[vapply(results, function(r) length(r$keep) == 0, logical(1))]
if (length(no_ensemble) > 0) {
  msg <- paste0("NO ENSEMBLE (every algorithm had cross-validated TSS < 0.5): ",
                paste(no_ensemble, collapse = "; "),
                ". Not projected. See outputs/part2_cv_performance.csv.")
  writeLines(msg, file.path(OUT_DIR, "part2_no_ensemble.txt"))
  warning(msg, call. = FALSE)
}
species <- setdiff(names(results), no_ensemble)
stopifnot("No species has a usable ensemble: stopping before projection. The cross-validation results are in outputs/part2_cv_performance.csv and outputs/part2_no_ensemble.txt." = length(species) > 0)

## 2.5 Projection: current + multi-GCM x multi-SSP, with MESS and uncertainty ----
ensemble_predict <- function(res, env_rast) {
  nd <- as.data.frame(env_rast, na.rm = FALSE)
  ok <- complete.cases(nd)
  s <- rep(NA_real_, nrow(nd)); s[ok] <- 0
  for (m in res$keep) {
    s[ok] <- s[ok] + res$weights[m] * pred_one(res$final[[m]], m, nd[ok, , drop = FALSE], res$preds)
  }
  out <- env_rast[[1]]; terra::values(out) <- s
  out
}

gcms   <- c("ACCESS-CM2", "MRI-ESM2-0", "MIROC6", "UKESM1-0-LL", "IPSL-CM6A-LR")
ssps   <- c("245", "585")                         # SSP2-4.5 and SSP5-8.5
times  <- c("2021-2040", "2041-2060", "2061-2080", "2081-2100")

get_future <- function(gcm, ssp, time) {
  r <- geodata::cmip6_world(model = gcm, ssp = ssp, time = time,
                            var = "bioc", res = 2.5, path = "data")
  names(r) <- paste0("bio", 1:19)
  r <- terra::mask(terra::crop(r, uk), uk)
  r[[names(bio_sel)]]
}

proj_summary <- list()
for (sp in species) {
  res <- results[[sp]]
  cur <- ensemble_predict(res, bio_sel_uk)   # always projected onto the UK
  terra::writeRaster(cur, sprintf(file.path(OUT_DIR, "%s_current.tif"), gsub(" ", "_", sp)), overwrite = TRUE)
  th <- mean(res$perf$threshold[res$perf$method %in% res$keep])

  for (ssp in ssps) for (tm in times) {
    layers <- lapply(gcms, function(g) ensemble_predict(res, get_future(g, ssp, tm)))
    st <- terra::rast(layers)
    mean_r <- terra::app(st, mean, na.rm = TRUE)
    sd_r   <- terra::app(st, sd, na.rm = TRUE)
    agree  <- terra::app(st >= th, mean, na.rm = TRUE)    # share of GCMs predicting suitable
    diff_r <- mean_r - cur                                 # difference map (common scale)
    tag <- sprintf("%s_SSP%s_%s", gsub(" ", "_", sp), ssp, tm)
    terra::writeRaster(mean_r, sprintf(file.path(OUT_DIR, "%s_mean.tif"), tag), overwrite = TRUE)
    terra::writeRaster(sd_r,   sprintf(file.path(OUT_DIR, "%s_sd.tif"), tag), overwrite = TRUE)
    terra::writeRaster(diff_r, sprintf(file.path(OUT_DIR, "%s_diff.tif"), tag), overwrite = TRUE)

    # Regional metrics (the corrected Table II)
    for (i in seq_len(nrow(uk))) {
      f <- terra::mask(terra::crop(mean_r, uk[i]), uk[i])
      c0 <- terra::mask(terra::crop(cur, uk[i]), uk[i])
      fv <- terra::values(f, na.rm = TRUE)[, 1]; cv0 <- terra::values(c0, na.rm = TRUE)[, 1]
      proj_summary[[length(proj_summary) + 1]] <- data.frame(
        species = sp, ssp = ssp, period = tm, country = uk$country[i],
        mean_suit = mean(fv), mean_suit_current = mean(cv0),
        delta_mean = mean(fv) - mean(cv0),
        pct_area_suitable = 100 * mean(fv >= th),
        pct_area_suitable_current = 100 * mean(cv0 >= th))
    }
  }
}
proj_summary <- do.call(rbind, proj_summary)
write.csv(proj_summary, file.path(OUT_DIR, "part2_regional_projection_summary.csv"), row.names = FALSE)

## 2.6 Extrapolation check (MESS) for one scenario, as an example ---------------
# predicts::mess(x = future_bio_stack, v = reference_values_at_training_points)
# Report where MESS < 0 (novel climate) and mask or flag those cells on maps.

###############################################################################
# NOTES FOR THE METHODS SECTION
# - Report: GBIF DOI, cleaning tests, n per species after thinning, VIF set,
#   background size and bias layer, block size, folds, algorithms retained,
#   thresholds, GCM list, package versions (sessionInfo()), and the seed.
# - Keep your ORIGINAL run as 'Configuration A' in the supplement and compare
#   A vs B explicitly (sensitivity analysis).
# - Do not claim 'northward shift' unless centroid shift or the regional metrics
#   above show it, with the inter-GCM spread (sd, agreement) reported.
###############################################################################
