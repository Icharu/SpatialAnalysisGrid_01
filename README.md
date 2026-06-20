# Cost-Constrained Spatially Balanced Sampling Design — RAPELD Grid, Reserva Adolpho Ducke

Reproducible R workflow that benchmarks the existing RAPELD/PPBio 30-plot grid at
Reserva Florestal Adolpho Ducke (Manaus, AM, Central Amazonia) against alternative
cost-aware sampling designs, evaluated under **uncertainty about the true spatial
structure**. Because no field response data exist yet, spatial structure is handled
by simulating Gaussian random fields across a factorial of plausible variogram
scenarios. See `../ducke-sampling-design-paper.docx` for the full pre-analysis
protocol (Materials and Methods is the spec this code implements).

## Approach

Designs (existing RAPELD grid, simple random, systematic, GRTS, cost-weighted GRTS,
simulated-annealing min-kriging-variance, MBHdesign) are compared at n = 30, 50, 100
on **mean & max kriging variance**, **spatial balance** (Voronoi area variance), and
**total travel cost**, then ranked for **robustness** across spatial-structure
scenarios. Results are reported as variance-vs-cost frontiers.

## Stack

R (>= 4.3) with `sf`, `terra`, `gstat`, `geoR`, `spsurvey`, `spsann`, `MBHdesign`,
`tmap`, `ggplot2`, `dplyr`. Dependencies are pinned with **renv**.

## Repository layout

```
config.R              project config: paths, CRS, frame spacing, seed, scenarios
R/                    reusable functions (utils.R, frame.R, ...)
scripts/              numbered, runnable pipeline (run from repo root)
  00_setup.R          renv bootstrap + dependency install + snapshot
  01_frame.R          boundary -> candidate tessellation -> exclusion masks
  02_covariates.R     DEM -> elevation/slope/HAND + NDVI + forest state (planned)
  02b_cost.R          accessibility cost surface (planned)
  03_simulate.R       Gaussian random fields across variogram scenarios (planned)
  04_designs.R        generate all candidate designs (planned)
  05_evaluate.R       metrics per (design x scenario x n) (planned)
  06_report.R         frontiers, robustness ranking, maps (planned)
data/raw/             cached open-data downloads (gitignored)
data/processed/       derived frame + covariate stack (gitignored)
outputs/figures/      maps and frontier plots (gitignored)
outputs/designs/      GeoPackage of each design's points (gitignored)
```

## Reproducibility

- **Open data only.** Downloads are cached in `data/raw/` and never re-fetched if
  present. Raster extents are kept tight to the reserve.
- Every script reads from `data/processed/` and writes deterministic outputs.
- Global RNG seed is set in `config.R` (`GLOBAL_SEED`) and re-set per script.
- Working CRS is **SIRGAS 2000 / UTM 21S (EPSG:31981)** — metres, for areas,
  distances, tessellation and travel cost.

## Usage

```bash
# from the repository root
Rscript scripts/00_setup.R     # one-time: install deps via renv, write renv.lock
Rscript scripts/01_frame.R     # build + render the sampling frame
```

`01_frame.R` writes `data/processed/ducke_boundary.gpkg`,
`data/processed/ducke_frame.gpkg`, and the review map
`outputs/figures/01_frame.png`.

### Boundary source

The default boundary is an offline, documented approximate polygon so the pipeline
runs without external services. For a publication-grade boundary, use the official
WDPA polygon (cached to `data/raw/`):

```bash
BOUNDARY_SOURCE=wdpa Rscript scripts/01_frame.R
```

## Status

Step 01 (frame) implemented. Steps 02–06 to follow incrementally, each stopping for
review. The real RAPELD 30-plot coordinates are provided at step 04.
