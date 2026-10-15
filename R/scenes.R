# Scenes, time series and overlap ---------------------------------------------
#
# Scene: one or more rasters that form a single image (e.g. Sentinel-2 bands
# in separate files, same date and same area).
# Time series: scenes of the same area on different dates.

extent_in <- function(extent, crs_from, crs_to) {
  e <- terra::ext(extent)
  if (!isFALSE(same_crs(crs_from, crs_to))) return(as.vector(e))
  tryCatch(as.vector(terra::project(e, from = crs_from$wkt, to = crs_to$wkt)),
           error = function(err) NULL)
}

# Intersection over union of two extents (xmin, xmax, ymin, ymax)
iou <- function(a, b) {
  w <- max(0, min(a[2], b[2]) - max(a[1], b[1]))
  h <- max(0, min(a[4], b[4]) - max(a[3], b[3]))
  inter <- w * h
  union <- (a[2] - a[1]) * (a[4] - a[3]) + (b[2] - b[1]) * (b[4] - b[3]) - inter
  if (union <= 0) return(0)
  inter / union
}

same_area <- function(a, b, threshold = 0.5) {
  if (a$crs$defined != b$crs$defined) return(FALSE)
  eb <- if (a$crs$defined) extent_in(b$extent, b$crs, a$crs) else b$extent
  !is.null(eb) && iou(a$extent, eb) >= threshold
}

single_date <- function(item) {
  if (length(item$unique_dates) == 1) item$unique_dates else as.Date(NA)
}

scene_compatible <- function(items, new) {
  all_items <- c(items, list(new))
  if (any(vapply(all_items, function(i) length(i$unique_dates) > 1, logical(1)))) return(FALSE)
  if (!identical(single_date(items[[1]]), single_date(new))) return(FALSE)
  bands <- lapply(all_items, function(i) stats::na.omit(i$bands$band))
  if (any(lengths(bands) == 0)) return(FALSE)
  if (anyDuplicated(unlist(bands))) return(FALSE)
  sensors <- unique(stats::na.omit(vapply(all_items, function(i) i$sensor$sensor, "")))
  if (length(sensors) > 1) return(FALSE)
  same_area(items[[1]], new)
}

group_scenes <- function(rasters) {
  groups <- list()
  for (it in rasters) {
    target <- NA
    for (k in seq_along(groups)) {
      if (scene_compatible(groups[[k]], it)) {
        target <- k
        break
      }
    }
    if (is.na(target)) groups[[length(groups) + 1]] <- list(it) else groups[[target]] <- c(groups[[target]], list(it))
  }
  lapply(seq_along(groups), function(k) finalize_scene(groups[[k]], paste0("C", k)))
}

finalize_scene <- function(items, id) {
  bands <- do.call(rbind, lapply(items, function(i) cbind(item = i$id, i$bands)))
  groups <- unique(bands$group[!is.na(bands$group)])
  n_spectral <- sum(bands$group %in% REFLECTIVE_GROUPS)
  threshold <- get_option("min_multispectral_bands", 4)
  dates <- sort(unique(do.call(c, lapply(items, function(i) i$unique_dates))))
  scales <- unique(vapply(items, function(i) i$scale$type, ""))
  sensors <- stats::na.omit(vapply(items, function(i) i$sensor$sensor, ""))
  a <- list()

  multispectral <- n_spectral >= threshold
  if (!multispectral && length(items) == 1 && n_spectral == 0 &&
      items[[1]]$n_layers >= threshold &&
      scales %in% c("reflectance_0_1", "int_10000", "landsat_c2")) {
    multispectral <- TRUE
    a[[length(a) + 1]] <- alert(id, sprintf(
      "The raster has %d layers with reflectance values, but I did not recognize the bands; I treated it as multispectral.",
      items[[1]]$n_layers), "info")
  }

  tags <- c("raster", sprintf("band:%s", setdiff(groups, "other")), sprintf("scale:%s", scales))
  if (multispectral) tags <- c(tags, "multispectral")
  if (length(items) == 1 && items[[1]]$dem$dem) tags <- c(tags, "dem")
  if (length(dates) >= 2) {
    tags <- c(tags, "time_series")
    if (length(dates) >= get_option("min_dates_long_series", 10)) tags <- c(tags, "long_series")
  }

  if (length(items) > 1) {
    res <- unique(t(vapply(items, function(i) round(i$resolution, 6), numeric(2))))
    if (nrow(res) > 1) {
      a[[length(a) + 1]] <- alert(id, "The bands of this scene have different resolutions; resample them to the same grid (terra::resample) before combining.", "info")
    }
    if (length(scales) > 1) {
      a[[length(a) + 1]] <- alert(id, "The files of this scene have different value scales; harmonize them before combining.")
    }
  }

  label <- if (length(items) == 1) {
    sprintf("'%s'", items[[1]]$name)
  } else {
    sprintf("scene with %d files%s", length(items),
            if (length(dates) == 1) paste0(" (", format(dates), ")") else "")
  }

  list(
    id = id, label = label,
    items = vapply(items, function(i) i$id, ""),
    dates = dates, bands = bands,
    sensor = if (length(sensors)) names(sort(table(sensors), decreasing = TRUE))[1] else NA_character_,
    scale = scales, multispectral = multispectral,
    crs = items[[1]]$crs, extent = items[[1]]$extent,
    tags = unique(tags),
    alerts = bind_alerts(a)
  )
}

undated_spectral <- function(scenes) {
  Filter(function(sc) length(sc$dates) == 0 && any(sc$bands$group %in% REFLECTIVE_GROUPS), scenes)
}

group_series <- function(scenes) {
  dated <- Filter(function(sc) length(sc$dates) == 1, scenes)
  undated <- undated_spectral(scenes)
  groups <- list()
  for (sc in dated) {
    target <- NA
    for (k in seq_along(groups)) {
      if (same_area(groups[[k]][[1]], sc)) {
        target <- k
        break
      }
    }
    if (is.na(target)) groups[[length(groups) + 1]] <- list(sc) else groups[[target]] <- c(groups[[target]], list(sc))
  }

  series <- list()
  for (g in groups) {
    dates <- sort(unique(do.call(c, lapply(g, function(sc) sc$dates))))
    if (length(dates) < 2) next
    id <- paste0("S", length(series) + 1)
    common_bands <- Reduce(intersect, lapply(g, function(sc) grep("^band:", sc$tags, value = TRUE)))
    tags <- c("raster", "time_series", common_bands)
    if (length(dates) >= get_option("min_dates_long_series", 10)) tags <- c(tags, "long_series")
    if (all(vapply(g, function(sc) sc$multispectral, logical(1)))) tags <- c(tags, "multispectral")

    a <- list()
    scales <- unique(unlist(lapply(g, function(sc) sc$scale)))
    if (length(scales) > 1) {
      a[[length(a) + 1]] <- alert(id, "The images in the series have different value scales; harmonize them before comparing dates.")
    }
    sensors <- unique(stats::na.omit(vapply(g, function(sc) sc$sensor, "")))
    if (length(sensors) > 1) {
      a[[length(a) + 1]] <- alert(id, sprintf(
        "The series mixes sensors (%s); harmonize the data before comparing dates.",
        paste(sensors, collapse = ", ")))
    }
    undated_here <- Filter(function(sc) same_area(g[[1]], sc), undated)
    if (length(undated_here)) {
      a[[length(a) + 1]] <- alert(id, sprintf(
        "In the same area there are images without an identified date (%s). Include the date in the file name (YYYYMMDD) or use terra::time().",
        paste(vapply(undated_here, function(sc) sc$label, ""), collapse = ", ")))
    }

    series[[length(series) + 1]] <- list(
      id = id, scenes = vapply(g, function(sc) sc$id, ""),
      items = unlist(lapply(g, function(sc) sc$items)),
      dates = dates, n_dates = length(dates),
      tags = unique(tags), alerts = bind_alerts(a)
    )
  }
  series
}

# Several undated images of the same area: possibly an unrecognized series
undated_alerts <- function(scenes) {
  undated <- undated_spectral(scenes)
  if (length(undated) < 2) return(NULL)
  for (i in seq_along(undated)) {
    for (j in seq_along(undated)) {
      if (i < j && same_area(undated[[i]], undated[[j]])) {
        return(alert("general", "There are several images of the same area without an identified date. If they are different dates, include the date in the file name (YYYYMMDD) or use terra::time() so rsguia recognizes the time series."))
      }
    }
  }
  NULL
}

check_overlap <- function(scene, vector) {
  out <- data.frame(scene = scene$id, vector = vector$id, status = "unknown",
                    proportion = NA_real_, same_crs = NA, stringsAsFactors = FALSE)
  if (!scene$crs$defined || !vector$crs$defined || !length(vector$geometries)) return(out)

  out$same_crs <- same_crs(scene$crs, vector$crs)
  crs_r <- sf::st_crs(scene$crs$wkt)
  e <- unname(scene$extent)
  box <- sf::st_as_sfc(sf::st_bbox(c(xmin = e[1], ymin = e[3], xmax = e[2], ymax = e[4]), crs = crs_r))
  prop <- tryCatch({
    s2 <- suppressMessages(sf::sf_use_s2(FALSE))
    on.exit(suppressMessages(sf::sf_use_s2(s2)), add = TRUE)
    geom <- sf::st_geometry(vector$object)
    geom <- geom[!sf::st_is_empty(geom)]
    if (!out$same_crs) geom <- sf::st_transform(geom, crs_r)
    mean(lengths(suppressMessages(sf::st_intersects(geom, box))) > 0)
  }, error = function(err) NA_real_)

  out$proportion <- prop
  out$status <- if (is.na(prop)) "unknown" else if (prop == 1) "full" else if (prop > 0) "partial" else "none"
  out
}

overlap_alerts <- function(o, scenes, vectors) {
  sc <- scenes[[match(o$scene, vapply(scenes, function(x) x$id, ""))]]
  vt <- vectors[[match(o$vector, vapply(vectors, function(x) x$id, ""))]]
  target <- paste(o$vector, "x", o$scene)
  a <- list()
  if (isFALSE(o$same_crs)) {
    a[[length(a) + 1]] <- alert(vt$id, sprintf(
      "Different CRSs (raster: %s; vector: %s). rsguia reprojected only to check the overlap; before analyzing, reproject the vector: sf::st_transform(v, terra::crs(r)).",
      crs_text(sc$crs), crs_text(vt$crs)))
  }
  if (o$status == "none") {
    a[[length(a) + 1]] <- alert(target, sprintf(
      "No feature of '%s' falls within %s. Check the CRS and whether the data cover the same region.",
      vt$name, sc$label))
  } else if (o$status == "partial") {
    a[[length(a) + 1]] <- alert(target, sprintf(
      "Only %s of the features of '%s' fall within %s.", fmt_pct(o$proportion), vt$name, sc$label), "info")
  } else if (o$status == "unknown") {
    a[[length(a) + 1]] <- alert(target, sprintf(
      "Could not check the overlap between '%s' and %s (missing CRS).", vt$name, sc$label))
  }
  bind_alerts(a)
}
