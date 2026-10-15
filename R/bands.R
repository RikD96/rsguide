# Band and sensor identification ----------------------------------------------
#
# Layer-name aliases live in inst/rules/bands.csv; each sensor's file-name
# pattern lives in inst/rules/sensors.csv.

REFLECTIVE_GROUPS <- c("coastal", "blue", "green", "red", "rededge", "nir",
                       "swir1", "swir2")

GROUP_LABELS <- c(
  coastal = "coastal/aerosol",
  blue = "blue",
  green = "green",
  red = "red",
  rededge = "red edge",
  nir = "near infrared",
  swir1 = "shortwave infrared 1",
  swir2 = "shortwave infrared 2",
  thermal = "thermal",
  quality = "quality/mask",
  other = "other"
)

band_table <- function() {
  tab <- read_internal_table("bands.csv")
  tab$alias <- normalize_band_name(tab$name)
  tab$order <- seq_len(nrow(tab))
  tab
}

sensor_table <- function() read_internal_table("sensors.csv")

# "T18LZQ_20230715T150721_B04_10m" -> "t18lzq_20230715t150721_b04"
normalize_band_name <- function(x) {
  x <- tolower(x)
  x <- sub("\\.(tif|tiff|jp2|img|vrt)$", "", x)
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- sub("_[0-9]{2,3}m$", "", x)
  gsub("^_+|_+$", "", x)
}

# Rows of the band table that match a (normalized) name. The whole name or
# its ending must match; only the longest alias is kept, so that "sr_b4"
# (Landsat) wins over "b4" (Sentinel-2).
band_candidates <- function(name, tab) {
  ok <- tab$alias == name | endsWith(name, paste0("_", tab$alias))
  cand <- tab[ok, , drop = FALSE]
  if (!nrow(cand)) return(cand)
  cand[nchar(cand$alias) == max(nchar(cand$alias)), , drop = FALSE]
}

identify_bands <- function(names, sensor = NULL, texts = character()) {
  tab <- band_table()
  sens <- sensor_table()
  cand <- lapply(normalize_band_name(names), band_candidates, tab = tab)

  specific <- setdiff(sens$sensor, "generic")
  points <- vapply(specific, function(s) {
    sum(vapply(cand, function(cc) s %in% cc$sensor, logical(1)))
  }, numeric(1))
  hints <- vapply(specific, function(s) {
    pattern <- sens$file_pattern[sens$sensor == s]
    !is.na(pattern) && any(grepl(pattern, texts, perl = TRUE))
  }, logical(1))
  # The file name only breaks ties if some band already matched the sensor
  total <- points + 2 * (hints & points > 0)

  tied <- character()
  if (!is.null(sensor)) {
    if (!sensor %in% sens$sensor) {
      cli::cli_abort(c("Unknown sensor: {.val {sensor}}.", "i" = "Options: {.val {sens$sensor}}."))
    }
    chosen <- sensor
    confidence <- "user"
  } else if (max(total) > 0) {
    tied <- names(total)[total == max(total)]
    chosen <- tied[1]
    confidence <- if (length(tied) > 1) {
      "low"
    } else if (hints[[chosen]] || points[[chosen]] >= 3) {
      "high"
    } else {
      "medium"
    }
  } else if (any(vapply(cand, function(cc) "generic" %in% cc$sensor, logical(1)))) {
    chosen <- "generic"
    confidence <- NA_character_
  } else {
    chosen <- NA_character_
    confidence <- NA_character_
  }

  rows <- lapply(seq_along(names), function(i) {
    cc <- cand[[i]]
    sel <- cc[cc$sensor %in% chosen, , drop = FALSE]
    if (!nrow(sel)) sel <- cc[cc$sensor == "generic", , drop = FALSE]
    if (!nrow(sel)) {
      return(data.frame(layer = i, name = names[i], band = NA_character_,
                        group = NA_character_, wavelength_nm = NA_real_,
                        order = NA_integer_, stringsAsFactors = FALSE))
    }
    sel <- sel[1, ]
    data.frame(layer = i, name = names[i], band = sel$band, group = sel$group,
               wavelength_nm = sel$wavelength_nm, order = sel$order,
               stringsAsFactors = FALSE)
  })

  list(
    sensor = chosen,
    label = if (is.na(chosen)) NA_character_ else sens$label[sens$sensor == chosen],
    confidence = confidence,
    tied = if (length(tied) > 1) tied else character(),
    score = total,
    bands = do.call(rbind, rows)
  )
}
