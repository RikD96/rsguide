# Printing --------------------------------------------------------------------

#' @export
print.rsguia_diagnosis <- function(x, ...) {
  cat(cli::rule(left = "rsguia diagnosis", line = 2), "\n", sep = "")
  types <- table(vapply(x$items, `[[`, "", "type"))
  cat("Inputs: ", paste(sprintf("%d %s", types, names(types)), collapse = ", "), "\n", sep = "")

  for (it in x$items) {
    cat("\n", cli::rule(left = sprintf("%s \u00b7 %s (%s)", it$id, it$name, it$type)), "\n", sep = "")
    if (it$type == "raster") print_raster(it) else print_vector(it)
  }

  combined <- Filter(function(sc) length(sc$items) > 1, x$scenes)
  if (length(combined)) {
    cat("\n", cli::rule(left = "Combined scenes"), "\n", sep = "")
    for (sc in combined) {
      bullet(sprintf("%s: %s - files %s", sc$id, sc$label, paste(sc$items, collapse = ", ")))
    }
  }

  if (length(x$series)) {
    cat("\n", cli::rule(left = "Time series"), "\n", sep = "")
    for (s in x$series) {
      bullet(sprintf("%s: %d dates, from %s to %s (files %s)", s$id, s$n_dates,
                     format(min(s$dates)), format(max(s$dates)), paste(s$items, collapse = ", ")))
    }
  }

  if (!is.null(x$overlaps)) {
    cat("\n", cli::rule(left = "Raster \u00d7 vector overlap"), "\n", sep = "")
    labels <- c(full = "full", partial = "partial", none = "none", unknown = "not checked")
    for (k in seq_len(nrow(x$overlaps))) {
      o <- x$overlaps[k, ]
      extra <- if (o$status == "partial") paste0(" (", fmt_pct(o$proportion), " of the features)") else ""
      bullet(sprintf("%s \u00d7 %s: %s%s", o$vector, o$scene, labels[[o$status]], extra))
    }
  }

  if (nrow(x$alerts)) {
    cat("\n", cli::rule(left = "Alerts"), "\n", sep = "")
    for (k in seq_len(nrow(x$alerts))) {
      sym <- if (x$alerts$level[k] == "warning") cli::col_yellow("!") else cli::col_blue("i")
      cat(sym, " [", x$alerts$item[k], "] ", x$alerts$message[k], "\n", sep = "")
    }
  }
  if (!is.null(x$suggestions)) print_suggestion_list(x$suggestions)
  invisible(x)
}

# Short list, used by print()
print_suggestion_list <- function(s) {
  cat("\n", cli::rule(left = sprintf("Suggested analyses (%d)", length(unique(s$id))), line = 2),
      "\n", sep = "")
  if (!nrow(s)) {
    cat("No analysis in the rules table applies to these data.\n")
    return(invisible())
  }
  for (category in unique(s$category)) {
    cat(cli::style_bold(category), "\n", sep = "")
    block <- s[s$category == category, , drop = FALSE]
    for (id in unique(block$id)) {
      r <- block[block$id == id, , drop = FALSE]
      targets <- unique(r$applies_to)
      where <- if (length(targets) <= 2) paste(targets, collapse = "; ") else
        sprintf("%d datasets", length(targets))
      cat("  ", cli::symbol$bullet, " ", r$analysis[1], " ",
          cli::col_grey(sprintf("[%s] %s %s", id, cli::symbol$arrow_right, where)), "\n", sep = "")
    }
  }
  cat("\n", cli::col_blue("i"), " Rationale and caveats: summary(). Example code: show_code(..., \"",
      s$id[1], "\"). Table to export: as.data.frame().\n", sep = "")
}

wrap <- function(text, indent, exdent = indent + 2) {
  width <- max(40, getOption("width", 80) - 2)
  cat(strwrap(text, width = width, indent = indent, exdent = exdent), sep = "\n")
}

# Detailed version, used by summary()
print_suggestions <- function(s, code = FALSE) {
  cat("\n", cli::rule(left = sprintf("Suggested analyses (%d)", length(unique(s$id))), line = 2),
      "\n", sep = "")
  if (!nrow(s)) {
    cat("No analysis in the rules table applies to these data.\n")
    return(invisible())
  }
  n <- 0
  for (category in unique(s$category)) {
    cat("\n", cli::style_bold(category), "\n", sep = "")
    block <- s[s$category == category, , drop = FALSE]
    for (id in unique(block$id)) {
      r <- block[block$id == id, , drop = FALSE]
      n <- n + 1
      cat(sprintf("%d. %s ", n, r$analysis[1]), cli::col_grey(sprintf("[%s]", id)), "\n", sep = "")
      wrap(paste("Applies to:", paste(unique(r$applies_to), collapse = "; ")), 3)
      wrap(paste("Why:", r$rationale[1]), 3)
      cat("   Caveats:\n")
      for (caveat in trimws(strsplit(r$caveats[1], "|", fixed = TRUE)[[1]])) {
        wrap(paste("-", caveat), 5, 7)
      }
      wrap(paste("Packages:", r$packages[1]), 3)
      if (code) {
        for (k in seq_len(nrow(r))) {
          if (is.na(r$code[k])) next
          cat("   Code", if (nrow(r) > 1) paste0(" (", r$applies_to[k], ")"), ":\n", sep = "")
          cat(paste0("     ", strsplit(r$code[k], "\n", fixed = TRUE)[[1]]), sep = "\n")
        }
      }
    }
  }
  if (!code) {
    cat("\n", cli::col_blue("i"), " To see the code: show_code(..., \"", s$id[1],
        "\") or summary(..., code = TRUE).\n", sep = "")
  }
}

bullet <- function(...) cat(cli::symbol$bullet, " ", ..., "\n", sep = "")

print_raster <- function(it) {
  res <- it$resolution_m
  res_txt <- if (abs(res[1] - res[2]) < 1e-6 * max(res)) fmt_num(res[1], if (res[1] < 10) 1 else 0) else
    paste(fmt_num(res, 1), collapse = " \u00d7 ")
  approx <- if (isTRUE(it$crs$lonlat)) "~" else ""
  unit <- if (it$crs$defined) " m" else " (CRS units)"
  bullet(sprintf("Layers: %d | Dimensions: %s rows \u00d7 %s columns | Resolution: %s%s%s",
                 it$n_layers, fmt_num(it$dims[1]), fmt_num(it$dims[2]), approx, res_txt, unit))
  bullet("CRS: ", crs_text(it$crs))
  e <- it$extent
  dig <- if (isTRUE(it$crs$lonlat)) 4 else 0
  bullet(sprintf("Extent: x from %s to %s; y from %s to %s",
                 fmt_num(e[1], dig), fmt_num(e[2], dig), fmt_num(e[3], dig), fmt_num(e[4], dig)))

  if (it$dem$dem) {
    bullet(sprintf("Likely DEM (%s confidence): %s", it$dem$confidence, it$dem$reason))
  } else if (!is.na(it$sensor$sensor)) {
    conf <- it$sensor$confidence
    conf <- if (is.na(conf)) "" else if (conf == "user") " (set by the user)" else
      sprintf(" (%s confidence)", conf)
    bullet("Likely sensor: ", it$sensor$label, conf)
  } else {
    bullet("Sensor: not identified")
  }

  b <- it$bands
  known <- !is.na(b$group)
  if (any(known)) {
    bullet("Bands: ", paste(sprintf("%s = %s", b$name[known], GROUP_LABELS[b$group[known]]), collapse = "; "))
  }
  if (any(!known) && !it$dem$dem) {
    bullet("Unrecognized layers: ", paste(utils::head(b$name[!known], 6), collapse = ", "),
           if (sum(!known) > 6) ", ..." else "")
  }
  bullet("Value scale: ", it$scale$description)
  range <- c(min(it$stats$min, na.rm = TRUE), max(it$stats$max, na.rm = TRUE))
  dig <- if (all(range == round(range)) && diff(range) > 2) 0 else 2
  bullet(sprintf("Values: minimum %s, maximum %s", fmt_num(range[1], dig), fmt_num(range[2], dig)))
  bullet("NA (no data): ", fmt_pct(max(it$stats$prop_na), 1),
         if (it$n_layers > 1) " in the layer with most NA" else "")
  if (length(it$unique_dates)) {
    d <- it$unique_dates
    txt <- if (length(d) <= 3) paste(format(d), collapse = ", ") else
      sprintf("%d dates, from %s to %s", length(d), format(min(d)), format(max(d)))
    bullet("Date(s): ", txt, " (", it$date_source, ")")
  }
}

print_vector <- function(it) {
  if (isTRUE(it$no_coords)) {
    bullet(sprintf("Table with %d rows, no recognized coordinates", it$n_features))
    return(invisible())
  }
  bullet(sprintf("Geometry: %s | Features: %s",
                 paste(it$geometries, collapse = ", "), fmt_num(it$n_features)))
  if (!is.null(it$table)) {
    bullet("Coordinates from columns: ", paste(it$table$coord_columns, collapse = " / "))
  }
  bullet("CRS: ", crs_text(it$crs))
  if (length(it$columns)) {
    bullet("Columns: ", paste(utils::head(it$columns, 8), collapse = ", "),
           if (length(it$columns) > 8) ", ..." else "")
  }
  if (length(it$class_columns)) {
    bullet("Possible class columns: ", paste(it$class_columns, collapse = ", "))
  }
}
