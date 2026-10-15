# Internal helpers ------------------------------------------------------------

`%||%` <- function(a, b) if (is.null(a)) b else a

# Reads a package option (e.g. options(rsguia.min_dates_long_series = 12))
get_option <- function(name, default) getOption(paste0("rsguia.", name), default)

# Reads a table from inst/rules/
read_internal_table <- function(file) {
  path <- system.file("rules", file, package = "rsguia", mustWork = TRUE)
  utils::read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8",
                  na.strings = c("", "NA"))
}

file_ext <- function(path) {
  b <- basename(path)
  ifelse(grepl("\\.[^.]+$", b), tolower(sub(".*\\.", "", b)), "")
}

strip_ext <- function(path) sub("\\.[^.]+$", "", basename(path))

# Alerts are stored as a data.frame (item, level, message)
alert <- function(item, message, level = "warning") {
  data.frame(item = item, level = level, message = message, stringsAsFactors = FALSE)
}

bind_alerts <- function(alerts) {
  alerts <- Filter(function(x) !is.null(x) && nrow(x) > 0, alerts)
  if (!length(alerts)) {
    return(data.frame(item = character(), level = character(), message = character(),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, alerts)
}

# Coordinate reference systems ------------------------------------------------

raster_crs <- function(r) {
  wkt <- terra::crs(r)
  if (!nzchar(wkt)) sf::NA_crs_ else sf::st_crs(wkt)
}

describe_crs <- function(crs) {
  if (is.na(crs)) {
    return(list(defined = FALSE, name = NA_character_, epsg = NA_integer_,
                lonlat = NA, wkt = NA_character_))
  }
  list(defined = TRUE,
       name = crs$Name %||% NA_character_,
       epsg = crs$epsg %||% NA_integer_,
       lonlat = isTRUE(sf::st_is_longlat(crs)),
       wkt = crs$wkt)
}

same_crs <- function(a, b) {
  if (!a$defined || !b$defined) return(NA)
  sf::st_crs(a$wkt) == sf::st_crs(b$wkt)
}

crs_text <- function(crs) {
  if (!crs$defined) return("not defined")
  if (is.na(crs$epsg)) crs$name else sprintf("%s (EPSG:%s)", crs$name, crs$epsg)
}

fmt_num <- function(x, digits = 0) {
  formatC(x, format = "f", digits = digits, big.mark = ",")
}

fmt_pct <- function(x, digits = 0) paste0(fmt_num(100 * x, digits), "%")
