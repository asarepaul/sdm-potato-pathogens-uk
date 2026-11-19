source("R/config.R")
require_set("n_background", "n_replicates", "replication", "seed")
suppressPackageStartupMessages({ library(terra); library(sf); library(sdm); library(dplyr); library(readr) })
set.seed(cfg$seed)

keep <- readLines(file.path(cfg$proc_dir, "retained_variables.txt"))
cur  <- rast(file.path(cfg$proc_dir, "bio_current.tif"))[[keep]]
occ  <- read_csv(file.path(cfg$proc_dir, "occurrences_thinned.csv"), show_col_types = FALSE)

eval_all <- list(); imp_all <- list()

for (sp in cfg$species) {
  slug <- gsub(" ", "_", sp)
  pres <- occ |> filter(species == sp)
  pres_v <- vect(pres, geom = c("longitude", "latitude"), crs = "EPSG:4326")

  # Background: random cells inside the minimum convex polygon around the presences.
  mcp <- convHull(pres_v)
  bg_area <- mask(crop(cur, mcp), mcp)
  bg <- spatSample(bg_area, size = cfg$n_background, method = "random", na.rm = TRUE, xy = TRUE)
  if (nrow(bg) < cfg$n_background)
    warning(sp, ": only ", nrow(bg), " background cells available inside the polygon")

  pres_env <- extract(cur, pres_v, ID = FALSE)
  train <- bind_rows(
    data.frame(occ = 1L, pres_env),
    data.frame(occ = 0L, bg[, names(cur), drop = FALSE])
  ) |> na.omit()
  stopifnot(all(c(0L, 1L) %in% train$occ))   # both classes must exist or AUC is meaningless
  write_csv(train, file.path(cfg$proc_dir, paste0("train_", slug, ".csv")))

  d <- sdmData(occ ~ ., train = train)
  args <- list(formula = occ ~ ., data = d, methods = cfg$methods,
               replication = cfg$replication, test.percent = cfg$test_percent)
  if (cfg$replication == "cv") args$cv.folds <- cfg$n_replicates else args$n <- cfg$n_replicates
  m <- do.call(sdm, args)
  saveRDS(m, file.path(cfg$proc_dir, paste0("model_", slug, ".rds")))

  info <- getModelInfo(m)
  ev <- getEvaluation(m, stat = c("AUC", "TSS"), wtest = "test.dep", opt = 2)
  ev <- left_join(info[, c("modelID", "method")], ev, by = c("modelID" = "modelID"))
  ev$species <- sp
  eval_all[[sp]] <- ev

  # Variable importance per method (AUC-based, test data).
  for (meth in cfg$methods) {
    ids <- info$modelID[info$method == meth]
    vi <- tryCatch(getVarImp(m, id = ids, wtest = "test.dep")@varImportanceMean$AUCtest,
                   error = function(e) NULL)
    if (!is.null(vi)) { vi$species <- sp; vi$method <- meth; imp_all[[paste(sp, meth)]] <- vi }
  }
}

ev_tbl <- bind_rows(eval_all)
write_csv(ev_tbl, file.path(cfg$tab_dir, "evaluation_by_run.csv"))
write_csv(ev_tbl |> group_by(species, method) |>
            summarise(AUC_mean = mean(AUC), AUC_sd = sd(AUC),
                      TSS_mean = mean(TSS), TSS_sd = sd(TSS), runs = n(), .groups = "drop"),
          file.path(cfg$tab_dir, "evaluation_summary.csv"))
if (length(imp_all)) write_csv(bind_rows(imp_all), file.path(cfg$tab_dir, "variable_importance.csv"))
