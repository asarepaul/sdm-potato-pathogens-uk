###############################################################################
# 01_robustness.R
# Robustness of the primary analysis (spatial block CV, target-group background)
# to the block-size cap and the random seed.
#
# Design: 3 block-size caps (500, 1,000, 1,500 km) x 5 seeds (101 to 105)
#         = 15 runs of sdm_corrected_workflow.R. Each run fits both modelled
#         species with 4 algorithms (glm, gam, rf, brt), so the output has
#         15 x 2 x 4 = 120 rows.
#
# How it works: for each run, a temporary copy of sdm_corrected_workflow.R is
# written with five lines changed (seed, block cap, CV type, background type,
# DIAGNOSTIC_ONLY = TRUE) and the output folder redirected. The workflow stops
# after the cross-validation table, so nothing is projected.
#
# Outputs go to outputs_robustness/, NOT outputs/, so the primary results are
# never overwritten. This folder is ignored by .gitignore (outputs_*/).
#
# Run from the configuration_B folder (the workflow uses relative paths):
#   setwd("<path>/configuration_B")
#   source("01_robustness.R")
# Expect it to take as long as 15 runs of the cross-validation part of the
# workflow. The results file is rewritten after every run, so a partial result
# survives if you stop it.
###############################################################################

WORKFLOW <- "sdm_corrected_workflow.R"
TMP_FILE <- "sdm_robust_tmp.R"
OUT_ROBUST <- "outputs_robustness"
CAPS_KM <- c(500, 1000, 1500)
SEEDS <- 101:105

stopifnot("Run from configuration_B: sdm_corrected_workflow.R not found" = file.exists(WORKFLOW),
          "Run from configuration_B: data/ folder not found" = dir.exists("data"))
dir.create(OUT_ROBUST, showWarnings = FALSE)

# Replace exactly one line that matches `pattern`; stop if it matches none or several.
patch_line <- function(x, pattern, replacement) {
  hit <- grep(pattern, x)
  if (length(hit) != 1L) {
    stop(sprintf("Pattern matched %d lines, expected 1: %s", length(hit), pattern), call. = FALSE)
  }
  x[hit] <- replacement
  x
}

robust <- list()

run_robust <- function(cap_km, seed) {
  x <- readLines(WORKFLOW)
  x <- patch_line(x, "^set\\.seed\\(2025\\)", sprintf("set.seed(%d)", seed))
  x <- patch_line(x, "^BLOCK_SIZE_CAP_M ", sprintf("BLOCK_SIZE_CAP_M <- %d", as.integer(cap_km * 1000)))
  x <- patch_line(x, "^CV_TYPE ", 'CV_TYPE <- "spatial"')
  x <- patch_line(x, "^BG_TYPE ", 'BG_TYPE <- "target_group"')
  x <- patch_line(x, "^DIAGNOSTIC_ONLY ", "DIAGNOSTIC_ONLY <- TRUE")
  x <- patch_line(x, "^OUT_DIR ", sprintf('OUT_DIR <- "%s"', OUT_ROBUST))
  writeLines(x, TMP_FILE)

  # The workflow ends a diagnostic run with stop(); that is expected, so try() it.
  invisible(capture.output(suppressWarnings(suppressMessages(
    try(source(TMP_FILE), silent = TRUE)))))

  perf_file <- file.path(OUT_ROBUST, "part2_cv_performance.csv")
  block_file <- file.path(OUT_ROBUST, "part2_block_size.csv")
  stopifnot("No results written: the run failed before the CV table" =
              file.exists(perf_file) && file.mtime(perf_file) >= Sys.time() - 3600)
  p <- read.csv(perf_file)
  b <- read.csv(block_file)
  p$cap_km <- cap_km
  p$seed <- seed
  p$block_used_km <- b$block_size_used_m[match(p$species, b$species)] / 1000
  robust[[length(robust) + 1]] <<- p
  write.csv(do.call(rbind, robust), file.path(OUT_ROBUST, "robustness_spatial.csv"),
            row.names = FALSE)
  # Remove this run's table so a failed later run cannot reuse it silently.
  file.remove(perf_file, block_file)
  cat("done:", cap_km, "km, seed", seed, "\n")
}

for (cap in CAPS_KM) for (sd in SEEDS) run_robust(cap, sd)

r <- do.call(rbind, robust)
cat("\nRows:", nrow(r), "(expected", length(CAPS_KM) * length(SEEDS) * 8, ")\n")
print(aggregate(cbind(AUC, TSS) ~ species + cap_km, r,
                function(v) round(c(mean = mean(v), min = min(v), max = max(v)), 2)))
print(table(r$cap_km, r$block_used_km))
cat("Models with TSS >= 0.5:", sum(r$TSS >= 0.5), "\n")
cat("Best TSS:", round(max(r$TSS), 3), "\n")
writeLines(capture.output(sessionInfo()), file.path(OUT_ROBUST, "sessionInfo_robustness.txt"))
