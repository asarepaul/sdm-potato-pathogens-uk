source("R/config.R")
suppressPackageStartupMessages({ library(sf); library(dplyr); library(readr); library(spThin); library(geodata) })

occ <- read_csv(file.path(cfg$raw_dir, "occurrences_raw.csv"), show_col_types = FALSE) |>
  mutate(longitude = suppressWarnings(as.numeric(longitude)),
         latitude  = suppressWarnings(as.numeric(latitude)))

log_row <- function(sp, step, n) data.frame(species = sp, step = step, n = n)
steps <- list()

# UK boundary: your OS file if provided, otherwise GADM level 1 (England, Scotland, Wales, Northern Ireland).
if (!is.na(cfg$uk_boundary_path)) {
  uk <- st_read(cfg$uk_boundary_path, quiet = TRUE)
  boundary_source <- cfg$uk_boundary_path
} else {
  uk <- st_as_sf(geodata::gadm("GBR", level = 1, path = cfg$raw_dir))
  boundary_source <- "GADM level 1 (geodata)"
}
uk <- st_transform(uk, 4326)
writeLines(boundary_source, file.path(cfg$proc_dir, "boundary_source.txt"))

thinned <- list()
for (sp in cfg$species) {
  d <- occ |> filter(species_label == sp)
  steps[[length(steps) + 1]] <- log_row(sp, "raw", nrow(d))

  d <- d |> filter(!is.na(longitude), !is.na(latitude),
                   between(longitude, -180, 180), between(latitude, -90, 90))
  steps[[length(steps) + 1]] <- log_row(sp, "valid coordinates", nrow(d))

  pts <- st_as_sf(d, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
  inside <- lengths(st_intersects(pts, st_union(uk))) > 0
  d <- d[inside, ]
  steps[[length(steps) + 1]] <- log_row(sp, "inside UK boundary", nrow(d))

  d <- d |> distinct(longitude, latitude, .keep_all = TRUE)
  steps[[length(steps) + 1]] <- log_row(sp, "exact duplicates removed", nrow(d))

  if (!is.na(cfg$seed)) set.seed(cfg$seed)
  th <- thin(d, lat.col = "latitude", long.col = "longitude", spec.col = "species_label",
             thin.par = cfg$thin_km, reps = 1, write.files = FALSE,
             locs.thinned.list.return = TRUE, verbose = FALSE)[[1]]
  names(th) <- c("longitude", "latitude")
  th$species <- sp
  steps[[length(steps) + 1]] <- log_row(sp, paste0("thinned ", cfg$thin_km, " km"), nrow(th))
  thinned[[sp]] <- th
}

write_csv(bind_rows(thinned), file.path(cfg$proc_dir, "occurrences_thinned.csv"))
log_tbl <- bind_rows(steps)
write_csv(log_tbl, file.path(cfg$tab_dir, "occurrence_cleaning_log.csv"))
print(log_tbl, n = Inf)
