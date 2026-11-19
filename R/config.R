# Central settings. Every value the manuscript leaves open is NA on purpose:
# the scripts stop until you set it, so nothing is silently invented.

cfg <- list(
  species = c("Fusarium sambucinum", "Phytophthora infestans", "Alternaria solani"),

  # Occurrence download
  spocc_sources = c("gbif", "inat", "idigbio", "vertnet", "ala", "obis"),
  occ_limit     = 10000,          # per species per source, adjust if a source truncates
  thin_km       = 1,              # manuscript: records within 1 km removed

  # Climate
  worldclim_res    = 2.5,         # arc-minutes, per manuscript
  vif_threshold    = 10,          # per manuscript
  future_model     = "MIROC6",       # confirmed by Kojo: the original run used MIROC6 only
  future_ssps      = c("245", "585"),
  future_periods   = c("2021-2040", "2041-2060", "2061-2080", "2081-2100"),
  uk_boundary_path = NA_character_,  # SET: path to your Ordnance Survey boundary file, or leave NA to use GADM
  nation_col       = "NAME_1",       # column holding England / Scotland / Wales / Northern Ireland

  # Modelling
  methods          = c("rf", "svm", "gam", "mars", "brt", "glm", "fda"),
  n_background     = NA_integer_,    # SET: pseudo-absences per species, must match what you report
  test_percent     = 30,             # manuscript: 70/30 split
  n_replicates     = NA_integer_,    # SET: replicate runs or folds, must match what you report
  replication      = NA_character_,  # SET: "sub" (repeated subsampling) or "cv"; manuscript only says cross validated
  seed             = NA_integer_,    # SET: any integer, record it

  # Paths
  raw_dir  = "data/raw",
  proc_dir = "data/processed",
  fig_dir  = "outputs/figures",
  tab_dir  = "outputs/tables"
)

require_set <- function(...) {
  nm <- c(...)
  bad <- nm[vapply(nm, function(k) is.null(cfg[[k]]) || any(is.na(cfg[[k]])), logical(1))]
  if (length(bad)) stop("Set these in R/config.R before running: ", paste(bad, collapse = ", "), call. = FALSE)
}
