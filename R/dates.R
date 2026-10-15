# Dates in file names, layer names and metadata -------------------------------

# Extracts the first date of each string. Recognizes YYYYMMDD, YYYY-MM-DD,
# YYYY_MM_DD and the MODIS Julian format (A + year + day of year).
extract_date <- function(x) {
  out <- rep(as.Date(NA), length(x))

  pattern <- paste0("(?<![0-9])(19|20)[0-9]{2}[-_.]?(0[1-9]|1[0-2])[-_.]?",
                    "(0[1-9]|[12][0-9]|3[01])(?![0-9])")
  m <- regexpr(pattern, x, perl = TRUE)
  if (any(m > 0)) {
    digits <- gsub("[^0-9]", "", regmatches(x, m))
    out[m > 0] <- as.Date(digits, format = "%Y%m%d")
  }

  missing <- which(is.na(out))
  m <- regexpr("(?<![0-9A-Za-z])A(19|20)[0-9]{5}(?![0-9])", x[missing], perl = TRUE)
  if (any(m > 0)) {
    s <- substring(regmatches(x[missing], m), 2)
    year <- as.integer(substr(s, 1, 4))
    day <- as.integer(substr(s, 5, 7))
    d <- as.Date(sprintf("%d-01-01", year)) + day - 1
    d[day < 1 | day > 366] <- NA
    out[missing[m > 0]] <- d
  }
  out
}

raster_dates <- function(r, sources) {
  n <- terra::nlyr(r)
  time <- tryCatch(terra::time(r), error = function(e) NULL)
  if ((inherits(time, "Date") || inherits(time, "POSIXt")) && any(!is.na(time))) {
    return(list(dates = as.Date(time), source = "metadata (terra::time)"))
  }
  d <- extract_date(names(r))
  if (any(!is.na(d))) return(list(dates = d, source = "layer names"))
  if (length(sources) == 1) {
    d <- extract_date(basename(sources))
    if (!is.na(d)) return(list(dates = rep(d, n), source = "file name"))
  }
  list(dates = rep(as.Date(NA), n), source = NA_character_)
}
