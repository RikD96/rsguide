# Diagnosis of vectors and tables with coordinates ----------------------------

GEOMETRIES <- c(POINT = "points", MULTIPOINT = "points",
                LINESTRING = "lines", MULTILINESTRING = "lines",
                POLYGON = "polygons", MULTIPOLYGON = "polygons")

diagnose_vector <- function(v, name, id, table = NULL) {
  sf_types <- unique(as.character(sf::st_geometry_type(v)))
  geometries <- unique(stats::na.omit(GEOMETRIES[sf_types]))
  crs <- describe_crs(sf::st_crs(v))
  columns <- setdiff(names(v), attr(v, "sf_column"))

  # Text/factor columns with few categories may be class labels
  class_columns <- columns[vapply(columns, function(cl) {
    x <- v[[cl]]
    (is.character(x) || is.factor(x)) &&
      length(unique(stats::na.omit(x))) %in% 2:50 &&
      length(unique(stats::na.omit(x))) < nrow(v)
  }, logical(1))]

  empty <- sum(sf::st_is_empty(v))
  invalid <- if ("polygons" %in% geometries) sum(!sf::st_is_valid(v), na.rm = TRUE) else 0L

  item <- list(
    id = id, type = if (is.null(table)) "vector" else "table", name = name,
    object = v, n_features = nrow(v), geometries = geometries,
    sf_types = sf_types, crs = crs,
    extent = if (nrow(v) > empty) as.vector(sf::st_bbox(v))[c(1, 3, 2, 4)] else rep(NA_real_, 4),
    columns = columns, class_columns = class_columns,
    empty = empty, invalid = invalid,
    table = table
  )

  a <- list(table$alerts)
  if (!crs$defined) {
    a[[length(a) + 1]] <- alert(id, "The vector has no CRS. Set it with sf::st_crs(v) <- 4326 (or the correct EPSG code).")
  }
  if (empty > 0) {
    a[[length(a) + 1]] <- alert(id, sprintf("%d features have empty geometry.", empty))
  }
  if (invalid > 0) {
    a[[length(a) + 1]] <- alert(id, sprintf(
      "%d polygons have invalid geometry; fix them with sf::st_make_valid().", invalid))
  }
  if (!length(geometries)) {
    a[[length(a) + 1]] <- alert(id, sprintf(
      "Unrecognized geometry type (%s).", paste(sf_types, collapse = ", ")))
  }
  item$alerts <- bind_alerts(a)
  item
}

COORD_PAIRS <- list(
  c("decimallongitude", "decimallatitude"),
  c("longitude", "latitude"),
  c("lon", "lat"), c("long", "lat"), c("lng", "lat"),
  c("x", "y"), c("coordx", "coordy"), c("xcoord", "ycoord"),
  c("easting", "northing"), c("utmx", "utmy"), c("utme", "utmn")
)

detect_coord_columns <- function(df) {
  normal <- gsub("[^a-z0-9]", "", tolower(names(df)))
  for (pair in COORD_PAIRS) {
    ix <- match(pair, normal)
    if (!anyNA(ix)) return(names(df)[ix])
  }
  NULL
}

as_number <- function(x) {
  if (is.numeric(x)) return(x)
  suppressWarnings(as.numeric(sub(",", ".", as.character(x), fixed = TRUE)))
}

diagnose_table <- function(df, name, id, table_crs = NULL) {
  cols <- detect_coord_columns(df)
  if (is.null(cols)) {
    return(list(
      id = id, type = "table", name = name, object = df, n_features = nrow(df),
      geometries = character(), crs = describe_crs(sf::NA_crs_),
      columns = names(df), no_coords = TRUE,
      alerts = alert(id, sprintf(
        "I found no coordinate columns in the table (columns: %s). Use names such as lon/lat, longitude/latitude or x/y.",
        paste(utils::head(names(df), 8), collapse = ", ")))
    ))
  }

  a <- list()
  x <- as_number(df[[cols[1]]])
  y <- as_number(df[[cols[2]]])
  df[[cols[1]]] <- x
  df[[cols[2]]] <- y
  ok <- is.finite(x) & is.finite(y)
  if (any(!ok)) {
    a[[length(a) + 1]] <- alert(id, sprintf(
      "%d rows without valid coordinates were ignored.", sum(!ok)))
  }
  df <- df[ok, , drop = FALSE]
  x <- x[ok]
  y <- y[ok]

  geo <- all(abs(x) <= 180) && all(abs(y) <= 90)
  if (!is.null(table_crs)) {
    crs <- sf::st_crs(table_crs)
  } else if (geo) {
    crs <- sf::st_crs(4326)
    a[[length(a) + 1]] <- alert(id, sprintf(
      "Columns %s/%s look like decimal degrees; I assumed WGS 84 (EPSG:4326). If they use another system, set table_crs.",
      cols[1], cols[2]), "info")
  } else if (all(abs(x) <= 90) && all(abs(y) <= 180)) {
    crs <- sf::NA_crs_
    a[[length(a) + 1]] <- alert(id, sprintf(
      "Values in %s exceed 90: latitude and longitude may be swapped.", cols[2]))
  } else {
    crs <- sf::NA_crs_
    a[[length(a) + 1]] <- alert(id, sprintf(
      "The coordinates (%s/%s) look projected (e.g. UTM). Set the system with table_crs, e.g. table_crs = 32718 (UTM 18S).",
      cols[1], cols[2]))
  }

  v <- sf::st_as_sf(df, coords = cols, crs = crs, remove = FALSE)
  diagnose_vector(v, name, id, table = list(coord_columns = cols, alerts = bind_alerts(a)))
}
