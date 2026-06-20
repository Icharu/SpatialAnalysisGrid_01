# scripts/01_frame.R -----------------------------------------------------------
# STEP 1 of the pipeline: build the spatial sampling frame for Reserva Ducke.
#
#   boundary polygon  ->  candidate-point tessellation  ->  exclusion masks
#
# Outputs (deterministic, seeded):
#   data/processed/ducke_boundary.gpkg   - reserve boundary (working CRS)
#   data/processed/ducke_frame.gpkg      - candidate points (cand_id, excluded)
#   outputs/figures/01_frame.png         - frame overview map (review artefact)
#
# Run from the repo root:  Rscript scripts/01_frame.R
# ------------------------------------------------------------------------------

suppressWarnings({
  source("config.R")
  source("R/utils.R")
  source("R/frame.R")
})
need_pkgs(c("sf", "ggplot2"))
set.seed(GLOBAL_SEED)

# --- 1. Boundary --------------------------------------------------------------
# Default "builtin" is offline & reproducible. Set BOUNDARY_SOURCE=wdpa to pull
# the official WDPA polygon (cached to data/raw/).
boundary_source <- Sys.getenv("BOUNDARY_SOURCE", unset = "builtin")
boundary <- get_ducke_boundary(source = boundary_source)
area_km2 <- as.numeric(sf::st_area(boundary)) / 1e6
log_msg(sprintf("boundary loaded (%s): %.1f km2", boundary_source, area_km2))

# --- 2. Candidate tessellation -----------------------------------------------
frame <- build_candidate_frame(boundary,
                               spacing = FRAME_SPACING_M,
                               type    = FRAME_TYPE)

# --- 3. Exclusion masks -------------------------------------------------------
# Water from OSM (cached/optional). Non-forest exclusion is added in
# 02_covariates.R once MapBiomas is available; the `excluded` flag carries over.
water <- get_water_mask(boundary, buffer_m = WATER_BUFFER_M)
frame <- apply_exclusions(frame, masks = list(water = water))

# --- 4. Persist ---------------------------------------------------------------
b_dest <- file.path(PATHS$processed, "ducke_boundary.gpkg")
f_dest <- file.path(PATHS$processed, "ducke_frame.gpkg")
write_gpkg(boundary, b_dest, layer = "ducke_boundary")
write_gpkg(frame,    f_dest, layer = "ducke_frame")
log_msg("wrote ", b_dest)
log_msg("wrote ", f_dest)

# --- 5. Review figure ---------------------------------------------------------
fig <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = boundary, fill = "grey95", colour = "grey20",
                   linewidth = 0.6) +
  ggplot2::geom_sf(data = frame[!frame$excluded, ],
                   colour = "#2c7fb8", size = 0.35, alpha = 0.8) +
  { if (any(frame$excluded))
      ggplot2::geom_sf(data = frame[frame$excluded, ],
                       colour = "#d7301f", size = 0.5) } +
  { if (!is.null(water))
      ggplot2::geom_sf(data = sf::st_sf(geometry = water),
                       fill = "#3690c0", colour = NA, alpha = 0.4) } +
  ggplot2::labs(
    title    = "Reserva Adolpho Ducke - sampling frame",
    subtitle = sprintf("%d candidate points @ %dm (%s); %d excluded; %.1f km2",
                       nrow(frame), FRAME_SPACING_M, FRAME_TYPE,
                       sum(frame$excluded), area_km2),
    caption  = sprintf("boundary: %s | CRS: %s", boundary_source, CRS_WORK)
  ) +
  ggplot2::theme_minimal(base_size = 11)

fig_dest <- file.path(PATHS$figures, "01_frame.png")
ggplot2::ggsave(fig_dest, fig, width = 7, height = 7, dpi = 150)
log_msg("wrote ", fig_dest)

log_msg("01_frame.R done. Review outputs/figures/01_frame.png before step 02.")
