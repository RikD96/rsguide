#' Diagnose remote sensing data
#'
#' Automatically identifies the type of data provided (raster, vector or
#' table with coordinates) and describes it: number of layers, resolution,
#' coordinate reference system (CRS), extent, missing values, bands and
#' likely sensor, value scale, whether the raster looks like a digital
#' elevation model (DEM), whether there is a time series and whether the
#' vectors overlap the rasters. By default it then suggests the possible
#' analyses with [suggest_analyses()].
#'
#' @param ... One or more datasets: `SpatRaster` objects (terra), `sf`
#'   objects, `data.frame`s with coordinate columns (e.g. `lon`/`lat`,
#'   `x`/`y`, `decimalLongitude`/`decimalLatitude`), paths to files (`.tif`,
#'   `.shp`, `.gpkg`, `.csv`, ...) or folders. Lists are also accepted.
#' @param sensor Optional. Forces the sensor when automatic identification
#'   fails or is ambiguous: `"sentinel2"`, `"landsat89"`, `"landsat457"` or
#'   `"generic"`.
#' @param table_crs Optional. CRS of the coordinates in tables (EPSG code or
#'   any string accepted by [sf::st_crs()]). If omitted, decimal degrees are
#'   assumed to be WGS 84 (EPSG:4326).
#' @param suggest If `TRUE` (default), also suggests the possible analyses
#'   with [suggest_analyses()].
#' @param rules Optional. Custom rules (`data.frame` or path to a CSV file)
#'   passed to [suggest_analyses()]; see [rsguide_rules()].
#'
#' @details
#' Large rasters are not read in full: statistics are estimated from a
#' regular sample of cells.
#'
#' Some thresholds can be changed with [options()]:
#' * `rsguide.min_multispectral_bands` (default 4): minimum number of spectral
#'   bands for the data to be considered multispectral;
#' * `rsguide.min_dates_long_series` (default 10): minimum number of dates for
#'   a time series to allow trend analysis;
#' * `rsguide.sample_size` (default 100000): number of cells sampled.
#'
#' @return An object of class `rsguide_diagnosis`: a list with the elements
#'   `items` (diagnosis of each dataset), `scenes`, `series`, `overlaps`,
#'   `contexts` (tag sets used by the recommendation rules), `alerts` and,
#'   if `suggest = TRUE`, `suggestions`.
#'
#' @examples
#' r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
#'                  extent = terra::ext(500000, 500200, 9150000, 9150200))
#' terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
#' names(r) <- c("B2", "B3", "B4", "B8")
#' diagnose(r)
#'
#' @export
diagnose <- function(..., sensor = NULL, table_crs = NULL, suggest = TRUE, rules = NULL) {
  inputs <- list(...)
  if (!length(inputs)) {
    cli::cli_abort("Provide at least one dataset to diagnose.")
  }
  names <- input_names(inputs, as.list(substitute(list(...)))[-1])
  raw <- collect_inputs(inputs, names)

  items <- list()
  count <- c(raster = 0, vector = 0, table = 0)
  prefix <- c(raster = "R", vector = "V", table = "T")
  for (b in raw) {
    count[b$type] <- count[b$type] + 1
    id <- paste0(prefix[[b$type]], count[[b$type]])
    items[[id]] <- switch(b$type,
      raster = diagnose_raster(b$object, b$name, id, sensor = sensor),
      vector = diagnose_vector(b$object, b$name, id),
      table = diagnose_table(b$object, b$name, id, table_crs = table_crs)
    )
    if (b$type != "raster") {
      items[[id]]$source <- b$source %||% NA_character_
      items[[id]]$sep <- b$sep
    }
  }

  rasters <- Filter(function(i) i$type == "raster", items)
  vectors <- Filter(function(i) i$type != "raster" && length(i$geometries) > 0, items)
  scenes <- if (length(rasters)) group_scenes(rasters) else list()
  series <- group_series(scenes)

  overlaps <- list()
  for (sc in scenes) for (vt in vectors) {
    overlaps[[length(overlaps) + 1]] <- check_overlap(sc, vt)
  }
  overlap_al <- lapply(overlaps, overlap_alerts, scenes = scenes, vectors = vectors)
  overlaps <- if (length(overlaps)) do.call(rbind, overlaps) else NULL

  alerts <- bind_alerts(c(
    lapply(items, `[[`, "alerts"),
    lapply(scenes, `[[`, "alerts"),
    lapply(series, `[[`, "alerts"),
    list(undated_alerts(scenes)),
    overlap_al
  ))
  alerts <- alerts[!duplicated(alerts[c("item", "message")]), , drop = FALSE]
  rownames(alerts) <- NULL

  diag <- structure(
    list(
      items = items,
      scenes = scenes,
      series = series,
      overlaps = overlaps,
      contexts = build_contexts(scenes, series, vectors, overlaps),
      alerts = alerts,
      parameters = list(sensor = sensor, table_crs = table_crs),
      created = Sys.time()
    ),
    class = "rsguide_diagnosis"
  )
  if (suggest) diag <- suggest_analyses(diag, rules)
  diag
}

input_names <- function(inputs, exprs) {
  nm <- names(inputs) %||% rep("", length(inputs))
  empty <- nm == ""
  nm[empty] <- vapply(exprs[empty], function(e) {
    paste(deparse(e, width.cutoff = 60L), collapse = "")
  }, "")
  nm
}

# Contexts: tag sets on which the rules are evaluated. One per scene, one per
# series, one per vector and one per scene x vector pair.
build_contexts <- function(scenes, series, vectors, overlaps) {
  ctx <- list()
  new_context <- function(id, label, items, tags) {
    list(id = id, label = label, items = items, tags = unique(tags))
  }
  for (sc in scenes) ctx[[sc$id]] <- new_context(sc$id, sc$label, sc$items, sc$tags)
  for (s in series) {
    ctx[[s$id]] <- new_context(s$id, sprintf("time series with %d dates", s$n_dates), s$items, s$tags)
  }
  for (vt in vectors) {
    tags <- c("vector", sprintf("vector:%s", vt$geometries))
    if (vt$type == "table") tags <- c(tags, "table")
    if (length(vt$class_columns)) tags <- c(tags, "vector:labeled")
    ctx[[vt$id]] <- new_context(vt$id, sprintf("'%s'", vt$name), vt$id, tags)
  }
  if (!is.null(overlaps)) {
    for (k in seq_len(nrow(overlaps))) {
      o <- overlaps[k, ]
      tags <- c(ctx[[o$scene]]$tags, ctx[[o$vector]]$tags)
      if (o$status %in% c("full", "partial")) tags <- c(tags, "overlap")
      if (isFALSE(o$same_crs)) tags <- c(tags, "crs_mismatch")
      id <- paste(o$scene, o$vector, sep = "+")
      ctx[[id]] <- new_context(id, paste(ctx[[o$scene]]$label, "+", ctx[[o$vector]]$label),
                               c(ctx[[o$scene]]$items, o$vector), tags)
    }
  }
  ctx
}
