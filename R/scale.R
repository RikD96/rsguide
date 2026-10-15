# Value scale and DEM detection -----------------------------------------------

SCALES <- list(
  reflectance_0_1 = list(description = "reflectance on a 0-1 scale",
                         factor = 1, offset = 0),
  int_10000 = list(description = "scaled integers (reflectance x 10,000)",
                   factor = 1e-4, offset = 0),
  landsat_c2 = list(description = "Landsat Collection 2 Level-2 integers (reflectance = value x 0.0000275 - 0.2)",
                    factor = 2.75e-5, offset = -0.2),
  int_8bit = list(description = "integers from 0 to 255 (8-bit image, probably for display)",
                  factor = NA, offset = NA),
  index = list(description = "values between -1 and 1 (probably an index already computed, such as NDVI)",
               factor = NA, offset = NA),
  categorical = list(description = "integers with few categories (probably a class map or mask)",
                     factor = NA, offset = NA),
  elevation = list(description = "continuous elevation values (probably in meters)",
                   factor = NA, offset = NA),
  unknown = list(description = "not recognized", factor = NA, offset = NA)
)

new_scale <- function(type) c(list(type = type), SCALES[[type]])

detect_scale <- function(values, bands, sensor) {
  spectral <- bands$group %in% REFLECTIVE_GROUPS
  cols <- if (any(spectral)) which(spectral) else seq_len(ncol(values))
  v <- as.vector(values[, cols])
  v <- v[is.finite(v)]
  if (!length(v)) return(new_scale("unknown"))

  mn <- min(v)
  mx <- max(v)
  integer <- all(v == round(v))

  if (!any(spectral) && ncol(values) == 1 && integer && length(unique(v)) <= 30) {
    return(new_scale("categorical"))
  }
  if (mx <= 1.6 && mn >= -1.05) {
    if (!any(spectral) && mn < -0.2) return(new_scale("index"))
    return(new_scale("reflectance_0_1"))
  }
  if (integer) {
    if (mn >= 0 && mx <= 255) return(new_scale("int_8bit"))
    valid <- v[v != 0]
    q <- stats::quantile(valid, c(0.01, 0.5, 0.99), names = FALSE)
    landsat <- isTRUE(sensor %in% c("landsat89", "landsat457"))
    sentinel <- isTRUE(sensor == "sentinel2")
    if (mx <= 65535 && ((landsat && q[2] >= 5000) || (!sentinel && q[1] >= 5000))) {
      return(new_scale("landsat_c2"))
    }
    if (q[3] <= 20000) {
      scale <- new_scale("int_10000")
      # Sentinel-2 L2A (baseline 04.00+) adds 1000 to the values: almost nothing falls below it
      if (sentinel && q[1] >= 1000) {
        scale$description <- "scaled integers with offset (reflectance = (value - 1000) / 10,000)"
        scale$offset <- -0.1
      }
      return(scale)
    }
  }
  new_scale("unknown")
}

# Names that suggest elevation (English, Portuguese and common products)
DEM_PATTERN <- paste0(
  "(^|[^a-z])(dem|dtm|dsm|mde|mdt|srtm|nasadem|elev[a-z]*|altitude|alos|",
  "aster|glo_?30|copdem|topo[a-z]*)([^a-z]|$)"
)

detect_dem <- function(name, sources, bands, values) {
  no <- list(dem = FALSE, confidence = NA_character_, reason = NA_character_)
  if (nrow(bands) != 1 || !is.na(bands$group[1])) return(no)

  v <- values[, 1]
  v <- v[is.finite(v)]
  if (length(v) < 2) return(no)
  mn <- min(v)
  mx <- max(v)
  plausible <- mn >= -500 && mx <= 9000 && (mx - mn) > 1 &&
    !(mx <= 1.6 && mn >= -1.05)

  texts <- tolower(c(name, bands$name, basename(sources)))
  name_hint <- any(grepl(DEM_PATTERN, texts, perl = TRUE))

  if (name_hint && plausible) {
    return(list(dem = TRUE, confidence = "high",
                reason = "the name suggests elevation and the values are consistent"))
  }
  continuous <- length(unique(v)) > 50
  eight_bit <- all(v == round(v)) && mn >= 0 && mx <= 255
  if (plausible && continuous && !eight_bit) {
    return(list(dem = TRUE, confidence = "medium",
                reason = sprintf("single band with continuous values between %s and %s, typical of elevation",
                                 fmt_num(mn), fmt_num(mx))))
  }
  no
}
