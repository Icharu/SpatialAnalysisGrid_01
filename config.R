# config.R ---------------------------------------------------------------------
# Central project configuration. Sourced by every script so that paths, the
# working CRS, the candidate-grid resolution and the global RNG seed are defined
# in exactly one place. Nothing here triggers downloads or heavy computation.
#
# Study: Cost-constrained spatially balanced sampling design at Reserva Adolpho
#        Ducke (Manaus, AM). See ducke-sampling-design-paper for the spec.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# --- Paths --------------------------------------------------------------------
# Project root: honour PROJ_ROOT env var if set, else assume the current working
# directory is the repo root (all scripts are documented to run from root).
PROJ_ROOT <- Sys.getenv("PROJ_ROOT", unset = getwd())
if (!dir.exists(file.path(PROJ_ROOT, "scripts"))) {
  stop("PROJ_ROOT (", PROJ_ROOT, ") has no scripts/ dir. Run from the repo root ",
       "or set Sys.setenv(PROJ_ROOT=...).")
}

PATHS <- list(
  root        = PROJ_ROOT,
  raw         = file.path(PROJ_ROOT, "data", "raw"),
  processed   = file.path(PROJ_ROOT, "data", "processed"),
  figures     = file.path(PROJ_ROOT, "outputs", "figures"),
  designs     = file.path(PROJ_ROOT, "outputs", "designs")
)
for (p in PATHS) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

# --- Coordinate reference systems --------------------------------------------
# Geographic CRS for downloads / lon-lat work.
CRS_GEO  <- "EPSG:4326"            # WGS84
# Projected working CRS: SIRGAS 2000 / UTM zone 21S — the Brazilian standard for
# central Amazonia (Ducke sits just east of the 60deg W zone 20/21 boundary).
# All areas, distances, tessellation and travel cost are computed in metres here.
CRS_WORK <- "EPSG:31981"

# --- Sampling frame parameters ------------------------------------------------
# Candidate-point tessellation spacing (metres). 250 m over ~100 km2 yields a
# manageable (~1.6k) candidate set while resolving the plateau-slope-valley
# gradient finely enough for kriging-variance evaluation. Tunable.
FRAME_SPACING_M <- 250

# Tessellation type for the candidate frame: "square" or "hexagonal".
FRAME_TYPE <- "square"

# Buffer (m) applied around mapped open water when building the exclusion mask.
WATER_BUFFER_M <- 30

# --- Spatial-structure scenarios (used from 03_simulate.R onward) -------------
# Factorial of variogram models: correlation range x nugget-to-sill ratio.
# Ranges are expressed in metres; chosen relative to the ~5 km grid extent.
VGM_RANGES_M  <- c(short = 500, medium = 1500, long = 4000)
VGM_NUGGET_RATIO <- c(low = 0.1, high = 0.5)   # nugget / (nugget + psill)
VGM_SILL      <- 1.0                            # total sill (variance), unit field
N_SIM_FIELDS  <- 50                             # GRF realisations per scenario

# --- Designs ------------------------------------------------------------------
DESIGN_SIZES <- c(30, 50, 100)                  # n: baseline + scaling scenarios

# --- Reproducibility ----------------------------------------------------------
GLOBAL_SEED <- 20260620
set.seed(GLOBAL_SEED)

invisible(TRUE)
