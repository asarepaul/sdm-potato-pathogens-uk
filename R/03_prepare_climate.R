source("R/config.R")
require_set("future_model")
suppressPackageStartupMessages({ library(terra); library(sf); library(usdm); library(geodata); library(readr) })

uk <- if (!is.na(cfg$uk_boundary_path)) st_read(cfg$uk_boundary_path, quiet = TRUE) else
  st_as_sf(geodata::gadm("GBR", level = 1, path = cfg$raw_dir))
uk <- st_transform(uk, 4326)
uk_v <- vect(uk)

bio_names <- paste0("bio", 1:19)
tidy <- function(r) { names(r) <- bio_names; r }
crop_uk <- function(r) mask(crop(r, uk_v), uk_v)

# Current climate
cur <- geodata::worldclim_global(var = "bio", res = cfg$worldclim_res, path = cfg$raw_dir)
cur <- crop_uk(tidy(cur))
writeRaster(cur, file.path(cfg$proc_dir, "bio_current.tif"), overwrite = TRUE)

# Collinearity: drop variables until every VIF is below the threshold.
vs <- vifstep(raster::stack(cur), th = cfg$vif_threshold)
keep <- vs@results$Variables
write_csv(vs@results, file.path(cfg$tab_dir, "vif_results.csv"))
writeLines(keep, file.path(cfg$proc_dir, "retained_variables.txt"))
message("Retained ", length(keep), " variables: ", paste(keep, collapse = ", "))

# Future climate: one file per scenario and period, same layer names as the current stack.
for (ssp in cfg$future_ssps) for (per in cfg$future_periods) {
  f <- geodata::cmip6_world(model = cfg$future_model, ssp = ssp, time = per,
                            var = "bioc", res = cfg$worldclim_res, path = cfg$raw_dir)
  f <- crop_uk(tidy(f))
  writeRaster(f, file.path(cfg$proc_dir, sprintf("bio_ssp%s_%s.tif", ssp, per)), overwrite = TRUE)
}
writeLines(c(paste("model:", cfg$future_model),
             paste("ssps:", paste(cfg$future_ssps, collapse = ", ")),
             paste("periods:", paste(cfg$future_periods, collapse = ", ")),
             paste("accessed:", Sys.Date())),
           file.path(cfg$proc_dir, "future_climate_source.txt"))
