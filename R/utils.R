# R/utils.R --------------------------------------------------------------------
# Small, dependency-light helpers shared across the pipeline.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

#' Log a timestamped message to stderr.
log_msg <- function(...) {
  message(sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

#' Require packages, erroring with an actionable message if any are missing.
need_pkgs <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing packages: ", paste(missing, collapse = ", "),
         "\nRun scripts/00_setup.R (renv) to install them.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Download a URL to a cache path, skipping if the file already exists.
#' Returns the local path. Honours the "open data, cache, never re-download" rule.
cached_download <- function(url, dest, mode = "wb", quiet = FALSE) {
  if (file.exists(dest) && file.info(dest)$size > 0) {
    if (!quiet) log_msg("cache hit: ", basename(dest))
    return(invisible(dest))
  }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!quiet) log_msg("downloading: ", url)
  utils::download.file(url, dest, mode = mode, quiet = quiet)
  invisible(dest)
}

#' Write an sf object to GeoPackage deterministically (overwrite, fixed layer).
write_gpkg <- function(x, dest, layer = NULL, quiet = TRUE) {
  need_pkgs("sf")
  layer <- layer %||% tools::file_path_sans_ext(basename(dest))
  if (file.exists(dest)) unlink(dest)
  sf::st_write(x, dest, layer = layer, quiet = quiet,
               delete_dsn = TRUE, driver = "GPKG")
  invisible(dest)
}
