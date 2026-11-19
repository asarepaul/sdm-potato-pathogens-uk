source("R/config.R")
suppressPackageStartupMessages({ library(spocc); library(dplyr); library(readr) })

get_one <- function(sp) {
  res <- occ(query = sp, from = cfg$spocc_sources, limit = cfg$occ_limit,
             has_coords = TRUE)
  df <- occ2df(res)
  df$species_label <- sp
  df$date_accessed <- as.character(Sys.Date())
  df
}

occ_all <- bind_rows(lapply(cfg$species, get_one))
write_csv(occ_all, file.path(cfg$raw_dir, "occurrences_raw.csv"))

# Raw counts per species and source, to compare against the manuscript.
counts <- occ_all |> count(species_label, prov, name = "n_raw")
write_csv(counts, file.path(cfg$tab_dir, "occurrence_counts_raw.csv"))
print(counts)
