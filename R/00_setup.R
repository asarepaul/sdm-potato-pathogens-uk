# Install packages once. Then record versions with renv::snapshot() so the repo is reproducible.
pkgs <- c("spocc", "sf", "terra", "spThin", "usdm", "sdm", "geodata",
          "dplyr", "readr", "ggplot2", "renv")
new <- setdiff(pkgs, rownames(installed.packages()))
if (length(new)) install.packages(new)

# The sdm package installs its model back-ends separately.
library(sdm)
sdm::installAll()

for (d in c("data/raw", "data/processed", "outputs/figures", "outputs/tables"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

writeLines(capture.output(sessionInfo()), "docs/sessionInfo_setup.txt")
