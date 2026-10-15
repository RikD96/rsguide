# Input normalization ---------------------------------------------------------
#
# Each input (object, file path or folder) becomes one or more "raw items":
# list(type = "raster" | "vector" | "table", object, name).

EXT_RASTER <- c("tif", "tiff", "vrt", "img", "jp2", "nc", "grd", "asc")
EXT_VECTOR <- c("shp", "gpkg", "geojson", "json", "kml")
EXT_TABLE <- c("csv", "txt", "tsv")

collect_inputs <- function(inputs, names) {
  items <- list()
  for (i in seq_along(inputs)) {
    items <- c(items, normalize_input(inputs[[i]], names[[i]]))
  }
  items
}

normalize_input <- function(x, name) {
  if (inherits(x, "SpatRaster")) {
    return(list(list(type = "raster", object = x, name = name)))
  }
  if (inherits(x, "SpatVector")) {
    return(list(list(type = "vector", object = sf::st_as_sf(x), name = name)))
  }
  if (inherits(x, "sfc")) {
    return(list(list(type = "vector", object = sf::st_sf(geometry = x), name = name)))
  }
  if (inherits(x, "sf")) {
    return(list(list(type = "vector", object = x, name = name)))
  }
  if (is.data.frame(x)) {
    return(list(list(type = "table", object = x, name = name)))
  }
  if (is.character(x)) {
    return(unlist(lapply(x, read_path), recursive = FALSE))
  }
  if (is.list(x)) {
    nm <- names(x) %||% rep("", length(x))
    nm[nm == ""] <- paste0(name, "[[", which(nm == ""), "]]")
    return(collect_inputs(x, nm))
  }
  cli::cli_abort(c(
    "I don't know how to diagnose objects of class {.cls {class(x)}}.",
    "i" = "Use a SpatRaster, an sf object, a data.frame with coordinates, or the path to a file or folder."
  ))
}

read_path <- function(path) {
  if (!file.exists(path)) {
    cli::cli_abort("File or folder not found: {.path {path}}")
  }
  if (dir.exists(path)) {
    files <- list.files(path, full.names = TRUE)
    files <- files[file_ext(files) %in% c(EXT_RASTER, EXT_VECTOR, EXT_TABLE)]
    if (!length(files)) {
      cli::cli_abort("The folder {.path {path}} has no recognizable rasters, vectors or tables.")
    }
    return(unlist(lapply(files, read_path), recursive = FALSE))
  }
  ext <- file_ext(path)
  name <- strip_ext(path)
  if (ext %in% EXT_RASTER) {
    return(list(list(type = "raster", object = terra::rast(path), name = name)))
  }
  if (ext %in% EXT_VECTOR) {
    return(list(list(type = "vector", object = sf::st_read(path, quiet = TRUE), name = name,
                     source = path)))
  }
  if (ext %in% EXT_TABLE) {
    df <- read_csv_any(path)
    return(list(list(type = "table", object = df, name = name, source = path,
                     sep = attr(df, "rsguia_sep"))))
  }
  cli::cli_abort("Unrecognized file format: {.path {path}}")
}

# Reads a CSV separated by comma, semicolon or tab, encoded in UTF-8 or
# latin1 (as saved by Excel on Windows)
read_csv_any <- function(path, na = "NA") {
  encoding <- if (all(validUTF8(readLines(path, warn = FALSE)))) "UTF-8" else "latin1"
  header <- readLines(path, n = 1, warn = FALSE, encoding = encoding)
  counts <- vapply(c(",", ";", "\t"), function(s) {
    lengths(regmatches(header, gregexpr(s, header, fixed = TRUE)))
  }, numeric(1))
  sep <- names(which.max(counts))
  df <- utils::read.table(path, header = TRUE, sep = sep, dec = if (sep == ";") "," else ".",
                          quote = "\"", stringsAsFactors = FALSE, check.names = FALSE,
                          comment.char = "", fill = TRUE, fileEncoding = encoding,
                          na.strings = na)
  attr(df, "rsguia_sep") <- sep
  df
}
