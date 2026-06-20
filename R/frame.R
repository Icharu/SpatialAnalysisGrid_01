# R/frame.R --------------------------------------------------------------------
# Build the spatial sampling frame for Reserva Adolpho Ducke:
#   boundary polygon  ->  candidate-point tessellation  ->  exclusion masks.
# Functions return sf objects in the projected working CRS (config CRS_WORK).
#
# Source order: source("config.R"); source("R/utils.R"); source("R/frame.R").

# --- Boundary -----------------------------------------------------------------

#' Documented approximate boundary of Reserva Florestal Adolpho Ducke.
#'
#' The reserve (~10,000 ha, managed by INPA on the northern edge of Manaus) spans
#' roughly 2 deg 55' - 3 deg 01' S and 59 deg 53' - 59 deg 59' W, i.e. a ~10 x 10 km
#' block of terra firme forest. This built-in polygon is the offline, always-runs
#' default so the whole pipeline is reproducible without external services. For a
#' publication-grade boundary, pass source = "wdpa" to substitute the official
#' WDPA protected-area polygon (cached to data/raw/).
#'
#' @return sf POLYGON in CRS_WORK (metres).
ducke_boundary_builtin <- function() {
  need_pkgs("sf")
  # lon, lat (WGS84) corners, NW -> NE -> SE -> SW -> close.
  ring <- matrix(c(
    -59.9833, -2.9167,
    -59.8833, -2.9167,
    -59.8833, -3.0167,
    -59.9833, -3.0167,
    -59.9833, -2.9167
  ), ncol = 2, byrow = TRUE)
  poly <- sf::st_polygon(list(ring))
  sf::st_sf(
    name      = "Reserva Florestal Adolpho Ducke",
    source    = "builtin-approximate",
    geometry  = sf::st_sfc(poly, crs = CRS_GEO)
  ) |>
    sf::st_transform(CRS_WORK)
}

#' Fetch the official WDPA polygon for Ducke via the wdpar package (cached).
#' Falls back with an informative error if wdpar / network are unavailable.
ducke_boundary_wdpa <- function(cache_dir = PATHS$raw) {
  need_pkgs(c("sf", "wdpar"))
  dest <- file.path(cache_dir, "wdpa_ducke.gpkg")
  if (file.exists(dest)) {
    log_msg("cache hit: wdpa_ducke.gpkg")
    return(sf::st_transform(sf::st_read(dest, quiet = TRUE), CRS_WORK))
  }
  log_msg("fetching Brazil WDPA via wdpar (large, one-time)...")
  bra <- wdpar::wdpa_fetch("BRA", wait = TRUE, download_dir = cache_dir)
  hit <- bra[grepl("Adolpho Ducke", bra$NAME, ignore.case = TRUE), ]
  if (nrow(hit) == 0) stop("No WDPA polygon matching 'Adolpho Ducke' found.")
  hit <- sf::st_make_valid(sf::st_union(hit))
  out <- sf::st_sf(name = "Reserva Florestal Adolpho Ducke",
                   source = "WDPA", geometry = hit)
  write_gpkg(sf::st_transform(out, CRS_GEO), dest, layer = "wdpa_ducke")
  sf::st_transform(out, CRS_WORK)
}

#' Get the Ducke boundary in the working CRS.
#' @param source "builtin" (default, offline) or "wdpa" (official, downloads).
get_ducke_boundary <- function(source = c("builtin", "wdpa"),
                               cache_dir = PATHS$raw) {
  source <- match.arg(source)
  b <- switch(source,
    builtin = ducke_boundary_builtin(),
    wdpa    = tryCatch(ducke_boundary_wdpa(cache_dir),
                       error = function(e) {
                         log_msg("WDPA fetch failed (", conditionMessage(e),
                                 "); falling back to builtin boundary.")
                         ducke_boundary_builtin()
                       })
  )
  sf::st_make_valid(b)
}

# --- Candidate tessellation ---------------------------------------------------

#' Discretise the boundary into a candidate-point tessellation.
#'
#' @param boundary sf polygon in CRS_WORK.
#' @param spacing  point spacing in metres (config FRAME_SPACING_M).
#' @param type     "square" or "hexagonal" (config FRAME_TYPE).
#' @return sf POINT layer of candidate locations clipped to the boundary, with a
#'         stable integer `cand_id`.
build_candidate_frame <- function(boundary,
                                   spacing = FRAME_SPACING_M,
                                   type    = FRAME_TYPE) {
  need_pkgs("sf")
  stopifnot(type %in% c("square", "hexagonal"))
  pts <- sf::st_make_grid(
    boundary,
    cellsize = spacing,
    what     = "centers",
    square   = identical(type, "square")
  )
  inside <- pts[boundary]                 # spatial filter: keep points in polygon
  out <- sf::st_sf(
    cand_id  = seq_along(inside),
    excluded = FALSE,
    geometry = inside
  )
  log_msg(sprintf("candidate frame: %d points at %dm (%s)",
                  nrow(out), spacing, type))
  out
}

# --- Exclusion masks ----------------------------------------------------------

#' Open-water polygons inside the boundary, from OpenStreetMap (cached).
#' Returns an (optionally buffered) sf polygon layer, or NULL if unavailable.
get_water_mask <- function(boundary, buffer_m = WATER_BUFFER_M,
                           cache_dir = PATHS$raw) {
  need_pkgs(c("sf"))
  dest <- file.path(cache_dir, "osm_water.gpkg")
  water <- NULL
  if (file.exists(dest)) {
    log_msg("cache hit: osm_water.gpkg")
    water <- sf::st_read(dest, quiet = TRUE)
  } else if (requireNamespace("osmdata", quietly = TRUE)) {
    bb <- sf::st_bbox(sf::st_transform(boundary, CRS_GEO))
    water <- tryCatch({
      q <- osmdata::opq(bbox = as.numeric(bb)) |>
        osmdata::add_osm_feature(key = "natural", value = "water")
      res <- osmdata::osmdata_sf(q)
      w <- res$osm_polygons
      if (is.null(w) || nrow(w) == 0) NULL else sf::st_transform(w, CRS_WORK)
    }, error = function(e) {
      log_msg("OSM water query failed (", conditionMessage(e), "); skipping.")
      NULL
    })
    if (!is.null(water)) write_gpkg(water["osm_id"], dest, layer = "osm_water")
  } else {
    log_msg("osmdata not installed; water mask skipped.")
  }
  if (is.null(water) || nrow(water) == 0) return(NULL)
  water <- sf::st_transform(water, CRS_WORK)
  if (buffer_m > 0) water <- sf::st_buffer(water, buffer_m)
  sf::st_make_valid(sf::st_union(water))
}

#' Flag candidate points falling inside any exclusion geometry.
#' Masks are kept as flags (not deleted) so 02_covariates.R can refine them
#' (e.g. with a MapBiomas non-forest mask) before the design step.
apply_exclusions <- function(frame, masks = list()) {
  need_pkgs("sf")
  masks <- Filter(Negate(is.null), masks)
  if (length(masks) == 0) {
    log_msg("no exclusion masks supplied; frame unchanged.")
    return(frame)
  }
  excl <- rep(FALSE, nrow(frame))
  for (m in masks) {
    hit <- lengths(sf::st_intersects(frame, m)) > 0
    excl <- excl | hit
  }
  frame$excluded <- frame$excluded | excl
  log_msg(sprintf("excluded %d / %d candidate points",
                  sum(frame$excluded), nrow(frame)))
  frame
}
