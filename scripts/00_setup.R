# scripts/00_setup.R -----------------------------------------------------------
# One-time environment bootstrap. Run from the repo root:  Rscript scripts/00_setup.R
# Initialises renv and installs the project dependencies, then snapshots a
# renv.lock for reproducibility. Safe to re-run (idempotent).

repos <- c(CRAN = "https://cloud.r-project.org")
options(repos = repos)

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

# Initialise renv on first run (creates renv/, .Rprofile, renv.lock).
if (!file.exists("renv.lock") && !dir.exists("renv")) {
  renv::init(bare = TRUE, restart = FALSE)
}

pkgs <- c(
  # spatial data handling
  "sf", "terra",
  # geostatistics: variograms, GRF simulation, kriging
  "gstat", "geoR",
  # sampling designs
  "spsurvey",      # GRTS
  "spsann",        # simulated-annealing min-variance designs
  "MBHdesign",     # balanced / quasi-random designs
  # data + viz
  "dplyr", "tidyr", "ggplot2", "tmap",
  # boundary / OSM acquisition (optional but used by frame.R hooks)
  "osmdata", "wdpar"
)

renv::install(pkgs)
renv::snapshot(prompt = FALSE)

message("Setup complete. renv.lock written. Next: Rscript scripts/01_frame.R")
