# summary() and as.data.frame() -----------------------------------------------

#' Summarize and export a diagnosis
#'
#' `summary()` shows an overview of the data and the full list of suggested
#' analyses, with rationale, caveats and packages (and, if `code = TRUE`, the
#' example code of each one). `as.data.frame()` turns the report into a
#' table, which can be saved with [utils::write.csv()].
#'
#' @param object,x An object of class `rsguide_diagnosis`, created by
#'   [diagnose()].
#' @param code If `TRUE`, includes the example code of each analysis.
#' @param type Which table to export: `"suggestions"` (one row per analysis
#'   and dataset), `"items"` (one row per diagnosed dataset) or `"alerts"`.
#' @param row.names,optional Ignored; present for compatibility with
#'   [base::as.data.frame()].
#' @param ... Ignored.
#'
#' @return `summary()` returns an object of class
#'   `summary.rsguide_diagnosis`; `as.data.frame()` returns a `data.frame`.
#'
#' @examples
#' r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
#'                  extent = terra::ext(500000, 500200, 9150000, 9150200))
#' terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
#' names(r) <- c("B2", "B3", "B4", "B8")
#' d <- diagnose(r)
#' summary(d)
#' report <- as.data.frame(d)
#' report[, c("analysis", "packages")]
#' as.data.frame(d, type = "items")
#'
#' # Saving the report as CSV (here to a temporary file)
#' file <- tempfile(fileext = ".csv")
#' utils::write.csv(report, file, row.names = FALSE)
#' unlink(file)
#'
#' @name diagnosis-summary
NULL

#' @rdname diagnosis-summary
#' @export
summary.rsguide_diagnosis <- function(object, code = FALSE, ...) {
  structure(
    list(items = as.data.frame(object, type = "items"),
         alerts = object$alerts,
         series = object$series,
         suggestions = object$suggestions,
         code = code),
    class = "summary.rsguide_diagnosis"
  )
}

#' @export
print.summary.rsguide_diagnosis <- function(x, ...) {
  cat(cli::rule(left = "rsguide diagnosis summary", line = 2), "\n", sep = "")
  for (k in seq_len(nrow(x$items))) {
    it <- x$items[k, ]
    cat(sprintf("%-4s", it$id), it$name, cli::col_grey(paste0("(", it$type, ")")), "\n")
    wrap(it$description, 5)
  }
  for (s in x$series) {
    cat("Time series:", sprintf("%d dates, from %s to %s", s$n_dates,
                                format(min(s$dates)), format(max(s$dates))), "\n")
  }
  n_warn <- sum(x$alerts$level == "warning")
  n_info <- sum(x$alerts$level != "warning")
  if (n_warn + n_info) {
    cat(sprintf("Alerts: %d warning(s) and %d note(s); see print() or as.data.frame(..., type = \"alerts\").\n",
                n_warn, n_info))
  }
  if (!is.null(x$suggestions)) print_suggestions(x$suggestions, code = x$code)
  invisible(x)
}

#' @rdname diagnosis-summary
#' @export
as.data.frame.rsguide_diagnosis <- function(x, row.names = NULL, optional = FALSE, ...,
                                           type = c("suggestions", "items", "alerts")) {
  type <- match.arg(type)
  switch(type,
    alerts = x$alerts,
    items = items_table(x),
    suggestions = {
      s <- x$suggestions
      if (is.null(s)) {
        cli::cli_abort("This diagnosis has no suggestions. Run {.fun suggest_analyses} first.")
      }
      s$files <- vapply(s$context, function(id) {
        items <- x$items[x$contexts[[id]]$items]
        files <- unlist(lapply(items, function(i) {
          f <- if (i$type == "raster") i$sources else i$source
          f <- f[!is.na(f)]
          if (length(f)) basename(f) else i$name
        }))
        paste(unique(files), collapse = "; ")
      }, "", USE.NAMES = FALSE)
      cols <- c("id", "analysis", "category", "applies_to", "files", "rationale",
                "caveats", "packages", "code")
      s <- s[, cols]
      rownames(s) <- NULL
      s
    }
  )
}

items_table <- function(x) {
  rows <- lapply(x$items, function(it) {
    raster <- it$type == "raster"
    src <- if (raster) paste(it$sources, collapse = "; ") else (it$source %||% NA_character_)
    bands <- if (raster) {
      b <- it$bands[!is.na(it$bands$group), , drop = FALSE]
      paste(sprintf("%s=%s", b$name, b$group), collapse = "; ")
    } else NA_character_
    data.frame(
      id = it$id, name = it$name, type = it$type,
      source = if (is.null(src) || is.na(src) || !nzchar(src)) NA_character_ else src,
      layers = if (raster) it$n_layers else NA_integer_,
      features = if (raster) NA_integer_ else it$n_features,
      geometry = if (raster) NA_character_ else paste(it$geometries, collapse = ", "),
      resolution_m = if (raster) round(it$resolution_m[1], 2) else NA_real_,
      crs = crs_text(it$crs),
      epsg = it$crs$epsg,
      sensor = if (raster) it$sensor$label else NA_character_,
      sensor_confidence = if (raster) it$sensor$confidence else NA_character_,
      bands = if (is.na(bands) || !nzchar(bands)) NA_character_ else bands,
      scale = if (raster) it$scale$type else NA_character_,
      dem = if (raster) it$dem$dem else NA,
      dates = if (raster && length(it$unique_dates)) paste(format(it$unique_dates), collapse = "; ") else NA_character_,
      max_prop_na = if (raster) round(max(it$stats$prop_na), 4) else NA_real_,
      description = describe_item(it),
      stringsAsFactors = FALSE
    )
  })
  tab <- do.call(rbind, rows)
  rownames(tab) <- NULL
  tab
}

# One line of text summarizing an item
describe_item <- function(it) {
  epsg <- if (is.na(it$crs$epsg)) crs_text(it$crs) else paste0("EPSG:", it$crs$epsg)
  if (it$type == "raster") {
    parts <- c(
      sprintf("%d layer%s", it$n_layers, if (it$n_layers > 1) "s" else ""),
      paste0(if (isTRUE(it$crs$lonlat)) "~" else "", fmt_num(it$resolution_m[1]), " m"),
      epsg,
      if (it$dem$dem) "likely DEM" else if (!is.na(it$sensor$sensor)) it$sensor$label,
      it$scale$description,
      if (length(it$unique_dates)) paste(format(it$unique_dates), collapse = ", ")
    )
  } else if (isTRUE(it$no_coords)) {
    parts <- sprintf("%d rows, no coordinates", it$n_features)
  } else {
    parts <- c(sprintf("%s %s", fmt_num(it$n_features), paste(it$geometries, collapse = "/")),
               epsg,
               if (length(it$class_columns)) paste("classes in:", paste(it$class_columns, collapse = ", ")))
  }
  paste(parts, collapse = " \u00b7 ")
}
