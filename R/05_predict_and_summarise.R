source("R/config.R")
suppressPackageStartupMessages({ library(terra); library(sf); library(sdm); library(geodata); library(dplyr); library(readr) })

keep <- readLines(file.path(cfg$proc_dir, "retained_variables.txt"))
uk <- if (!is.na(cfg$uk_boundary_path)) st_read(cfg$uk_boundary_path, quiet = TRUE) else
  st_as_sf(geodata::gadm("GBR", level = 1, path = cfg$raw_dir))
uk_v <- vect(st_transform(uk, 4326))

scen <- c(list(current = file.path(cfg$proc_dir, "bio_current.tif")),
          setNames(as.list(file.path(cfg$proc_dir,
                   outer(cfg$future_ssps, cfg$future_periods, function(s, p) sprintf("bio_ssp%s_%s.tif", s, p)))),
                   as.vector(outer(cfg$future_ssps, cfg$future_periods, function(s, p) sprintf("ssp%s_%s", s, p)))))

rows <- list()
for (sp in cfg$species) {
  slug <- gsub(" ", "_", sp)
  m <- readRDS(file.path(cfg$proc_dir, paste0("model_", slug, ".rds")))
  for (nm in names(scen)) {
    env <- rast(scen[[nm]])[[keep]]
    out <- file.path(cfg$proc_dir, sprintf("suit_%s_%s.tif", slug, nm))
    # Ensemble weighted by TSS, as in the manuscript.
    ensemble(m, newdata = raster::stack(env), filename = out, overwrite = TRUE,
             setting = list(method = "weighted", stat = "TSS", opt = 2))
    s <- rast(out)
    z <- extract(s, uk_v, fun = mean, na.rm = TRUE, ID = FALSE)
    rows[[length(rows) + 1]] <- data.frame(species = sp, scenario = nm,
                                           nation = as.data.frame(uk_v)[[cfg$nation_col]],
                                           mean_suitability = z[[1]])
    png(file.path(cfg$fig_dir, sprintf("map_%s_%s.png", slug, nm)), width = 900, height = 1100, res = 150)
    plot(s, main = paste(sp, nm), range = c(0, 1)); plot(uk_v, add = TRUE)
    dev.off()
  }
}

tab <- bind_rows(rows)
write_csv(tab, file.path(cfg$tab_dir, "suitability_by_nation.csv"))

# Change relative to current, so any claim about a shift rests on a number.
cur <- tab |> filter(scenario == "current") |> select(species, nation, current = mean_suitability)
chg <- tab |> filter(scenario != "current") |> left_join(cur, by = c("species", "nation")) |>
  mutate(change = mean_suitability - current)
write_csv(chg, file.path(cfg$tab_dir, "suitability_change_vs_current.csv"))
