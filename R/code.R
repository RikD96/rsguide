# Building the example code ---------------------------------------------------
#
# Templates live in inst/templates/<id>.R and use placeholders in braces:
#   {load_raster:img}    lines that create the object `img` with the raster
#   {load_vector:points} lines that create the object `points` (sf)
#   {load_series:imgs}   lines that create the list `imgs`, one image per date
#   {scale}              line that converts `img` to 0-1 reflectance
#   {conversion}         the same conversion as an expression of `x`
#   {index_expr}, {index_name}  NDVI (if red and NIR exist) or the first layer
#   {dates}              vector of dates of the series
#   {class_column}       class column of the vector (training samples)
#   {blue}, {green}, {red}, {rededge}, {nir}, {swir1}, {swir2}...  layer names

read_template <- function(rule) {
  if ("template" %in% names(rule) && !is.na(rule$template) && nzchar(rule$template)) {
    file <- rule$template
    if (!file.exists(file)) file <- system.file("templates", file, package = "rsguide")
  } else {
    file <- system.file("templates", paste0(rule$id, ".R"), package = "rsguide")
  }
  if (!nzchar(file) || !file.exists(file)) return(NA_character_)
  paste(readLines(file, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

r_string <- function(x) encodeString(x, quote = "\"")

build_code <- function(rule, cx, diag) {
  template <- read_template(rule)
  if (is.na(template)) return(NA_character_)

  parts <- strsplit(cx$id, "+", fixed = TRUE)[[1]]
  by_id <- function(lst, ids) {
    found <- Filter(function(x) x$id %in% ids, lst)
    if (length(found)) found[[1]] else NULL
  }
  series <- by_id(diag$series, parts)
  scene <- by_id(diag$scenes, parts)
  if (is.null(scene) && !is.null(series)) scene <- by_id(diag$scenes, series$scenes[1])
  vector <- diag$items[intersect(parts, names(diag$items))]
  vector <- Filter(function(i) i$type != "raster", vector)
  vector <- if (length(vector)) vector[[1]] else NULL

  replace_block <- function(txt, marker, generate) {
    pattern <- paste0("\\{", marker, ":([A-Za-z_.][A-Za-z0-9_.]*)\\}")
    while (grepl(pattern, txt)) {
      m <- regmatches(txt, regexec(pattern, txt))[[1]]
      txt <- sub(m[1], generate(m[2]), txt, fixed = TRUE)
    }
    txt
  }
  txt <- replace_block(template, "load_raster", function(name) scene_code(scene, diag, name))
  txt <- replace_block(txt, "load_vector", function(name) vector_code(vector, name))
  txt <- replace_block(txt, "load_series", function(name) series_code(series, scene, diag, name))

  values <- list()
  if (!is.null(scene)) {
    bands <- scene$bands[!is.na(scene$bands$group), , drop = FALSE]
    bands <- bands[order(bands$order), , drop = FALSE]
    for (g in unique(bands$group)) values[[g]] <- bands$name[bands$group == g][1]
    conv <- scale_conversion(diag$items[[scene$items[1]]]$scale)
    values$scale <- if (is.na(conv$expr)) conv$comment else
      paste0("img <- ", sub("x", "img", conv$expr, fixed = TRUE), "  ", conv$comment)
    values$conversion <- if (is.na(conv$expr)) "x" else conv$expr
    has_ndvi <- all(c("red", "nir") %in% names(values))
    values$index_name <- if (has_ndvi) "NDVI" else "first layer value"
    values$index_expr <- if (has_ndvi) {
      sprintf("(x[[\"%s\"]] - x[[\"%s\"]]) / (x[[\"%s\"]] + x[[\"%s\"]])",
              values$nir, values$red, values$nir, values$red)
    } else {
      "x[[1]]"
    }
    dates <- if (!is.null(series)) series$dates else scene$dates
    values$dates <- sprintf("as.Date(c(%s))", paste(r_string(format(dates)), collapse = ", "))
  }
  if (!is.null(vector) && length(vector$class_columns)) values$class_column <- vector$class_columns[1]
  if (is.null(values$class_column)) values$class_column <- "class"
  for (g in names(GROUP_LABELS)) {
    if (is.null(values[[g]])) values[[g]] <- paste0("BAND_NAME_", toupper(g))
  }
  for (nm in names(values)) txt <- gsub(paste0("{", nm, "}"), values[[nm]], txt, fixed = TRUE)
  txt
}

scale_conversion <- function(scale) {
  to_reflectance <- "# converts to 0-1 reflectance"
  switch(scale$type,
    int_10000 = if (isTRUE(scale$offset == -0.1)) {
      list(expr = "(x - 1000) / 10000", comment = "# removes the offset and converts to 0-1 reflectance")
    } else {
      list(expr = "x / 10000", comment = to_reflectance)
    },
    landsat_c2 = list(expr = "x * 0.0000275 - 0.2", comment = to_reflectance),
    reflectance_0_1 = list(expr = NA_character_, comment = "# values are already 0-1 reflectance"),
    list(expr = NA_character_, comment = "# check the value scale before computing indices")
  )
}

# R expression that reads a single diagnosed raster
raster_expr <- function(item) {
  if (length(item$sources) == 1) sprintf("terra::rast(%s)", r_string(item$sources)) else item$name
}

scene_code <- function(scene, diag, name) {
  if (is.null(scene)) return(paste0(name, " <- terra::rast(\"YOUR_RASTER.tif\")"))
  items <- diag$items[scene$items]
  if (length(items) == 1) return(paste(name, "<-", raster_expr(items[[1]])))
  # Bands in separate files: stack them on the grid of the finest band
  sources <- vapply(items, function(i) if (length(i$sources) == 1) i$sources else NA_character_, "")
  res <- vapply(items, function(i) i$resolution[1], numeric(1))
  if (anyNA(sources)) {
    objs <- vapply(items, function(i) i$name, "")
    return(sprintf("%s <- c(%s)  # put the bands on the same grid if needed", name, paste(objs, collapse = ", ")))
  }
  ord <- c(which.min(res), setdiff(seq_along(sources), which.min(res)))
  paste0(
    "files <- c(\n  ", paste(r_string(unname(sources[ord])), collapse = ",\n  "), "\n)\n",
    "reference <- terra::rast(files[1])  # reference grid (finest resolution)\n",
    name, " <- terra::rast(lapply(files, function(f) terra::resample(terra::rast(f), reference, method = \"near\")))"
  )
}

series_code <- function(series, scene, diag, name) {
  if (is.null(series)) {
    # Series inside a single raster (one layer per date)
    return(sprintf("%s <- as.list(%s)  # one layer per date",
                   name, if (is.null(scene)) "YOUR_RASTER" else raster_expr(diag$items[[scene$items[1]]])))
  }
  scenes <- Filter(function(sc) sc$id %in% series$scenes, diag$scenes)
  scenes <- scenes[order(vapply(scenes, function(sc) as.numeric(sc$dates[1]), numeric(1)))]
  exprs <- vapply(scenes, function(sc) {
    items <- diag$items[sc$items]
    if (length(items) == 1) return(raster_expr(items[[1]]))
    sources <- vapply(items, function(i) if (length(i$sources) == 1) i$sources else i$name, "")
    sprintf("terra::rast(c(%s))", paste(r_string(sources), collapse = ", "))
  }, "")
  paste0(name, " <- list(  # in date order\n  ", paste(exprs, collapse = ",\n  "), "\n)")
}

vector_code <- function(vector, name) {
  if (is.null(vector)) return(paste0(name, " <- sf::st_read(\"YOUR_VECTOR.gpkg\")"))
  has_source <- !is.null(vector$source) && !is.na(vector$source)
  if (vector$type == "vector") {
    src <- if (has_source) sprintf("sf::st_read(%s)", r_string(vector$source)) else vector$name
    return(paste(name, "<-", src))
  }
  tab <- if (has_source) {
    sep <- vector$sep %||% ","
    switch(sep,
      ";" = sprintf("utils::read.csv2(%s)", r_string(vector$source)),
      "," = sprintf("utils::read.csv(%s)", r_string(vector$source)),
      sprintf("utils::read.csv(%s, sep = %s)", r_string(vector$source), r_string(sep)))
  } else {
    vector$name
  }
  coords <- paste(r_string(vector$table$coord_columns), collapse = ", ")
  if (is.na(vector$crs$epsg)) {
    return(sprintf("%s <- sf::st_as_sf(%s, coords = c(%s))  # set the CRS: crs = <EPSG code>",
                   name, tab, coords))
  }
  sprintf("%s <- sf::st_as_sf(%s, coords = c(%s), crs = %s)", name, tab, coords, vector$crs$epsg)
}
