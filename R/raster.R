# Raster diagnosis ------------------------------------------------------------

# Reads at most `n` cells (regular sample) to estimate statistics without
# loading large rasters into memory.
sample_values <- function(r, n = get_option("sample_size", 1e5)) {
  if (terra::ncell(r) <= n) {
    v <- terra::values(r, mat = TRUE)
  } else {
    v <- as.matrix(terra::spatSample(r, size = n, method = "regular",
                                     na.rm = FALSE, as.df = TRUE))
  }
  colnames(v) <- names(r)
  v
}

diagnose_raster <- function(r, name, id, sensor = NULL) {
  sources <- terra::sources(r)
  sources <- unique(sources[nzchar(sources)])
  layer_names <- names(r)
  values <- sample_values(r)
  crs <- describe_crs(raster_crs(r))
  ext <- unname(as.vector(terra::ext(r)))

  res <- terra::res(r)
  res_m <- if (isTRUE(crs$lonlat)) {
    res * 111320 * c(cos(mean(ext[3:4]) * pi / 180), 1)
  } else {
    res
  }

  ident <- identify_bands(layer_names, sensor = sensor, texts = c(basename(sources), name))
  dem <- detect_dem(name, sources, ident$bands, values)
  scale <- if (dem$dem) new_scale("elevation") else detect_scale(values, ident$bands, ident$sensor)
  dates <- raster_dates(r, sources)

  stats <- data.frame(
    layer = layer_names,
    min = apply(values, 2, function(x) if (all(is.na(x))) NA else min(x, na.rm = TRUE)),
    max = apply(values, 2, function(x) if (all(is.na(x))) NA else max(x, na.rm = TRUE)),
    mean = apply(values, 2, mean, na.rm = TRUE),
    prop_na = colMeans(is.na(values)),
    row.names = NULL, stringsAsFactors = FALSE
  )

  item <- list(
    id = id, type = "raster", name = name, sources = sources, object = r,
    n_layers = terra::nlyr(r), layer_names = layer_names,
    dims = c(rows = terra::nrow(r), cols = terra::ncol(r)),
    resolution = res, resolution_m = res_m,
    crs = crs, extent = ext,
    stats = stats,
    sensor = ident[c("sensor", "label", "confidence", "tied")],
    bands = ident$bands,
    scale = scale,
    dem = dem,
    dates = dates$dates,
    unique_dates = sort(unique(dates$dates[!is.na(dates$dates)])),
    date_source = dates$source
  )
  item$alerts <- raster_alerts(item, values)
  item
}

raster_alerts <- function(item, values) {
  id <- item$id
  a <- list()
  if (!item$crs$defined) {
    a[[length(a) + 1]] <- alert(id, "The raster has no coordinate reference system (CRS). Set it with terra::crs(r) <- \"EPSG:...\" before combining it with other data.")
  }
  high_na <- item$stats$layer[item$stats$prop_na > 0.5]
  if (length(high_na)) {
    a[[length(a) + 1]] <- alert(id, sprintf(
      "More than half of the pixels are NA (no data) in: %s. Check clouds, masks or the crop.",
      paste(high_na, collapse = ", ")))
  }
  complete <- values[stats::complete.cases(values), , drop = FALSE]
  if (nrow(complete) && !item$scale$type %in% c("categorical", "elevation")) {
    zeros <- mean(rowSums(complete != 0) == 0)
    if (zeros > 0.05) {
      a[[length(a) + 1]] <- alert(id, sprintf(
        "%s of the pixels are 0 in every layer; this may be an undeclared \"no data\" value. If so, use terra::NAflag(r) <- 0.",
        fmt_pct(zeros)))
    }
  }
  if (all(is.na(item$bands$group)) && !item$dem$dem && item$n_layers > 1) {
    a[[length(a) + 1]] <- alert(id, sprintf(
      "I did not recognize the layer names (%s). Rename them so rsguide can identify the bands, e.g. names(r) <- c(\"blue\", \"green\", \"red\", \"nir\").",
      paste(utils::head(item$layer_names, 4), collapse = ", ")))
  }
  if (length(item$sensor$tied)) {
    sens <- sensor_table()
    labels <- sens$label[match(item$sensor$tied, sens$sensor)]
    a[[length(a) + 1]] <- alert(id, sprintf(
      "The band names match more than one sensor (%s). I assumed %s; if that is wrong, use diagnose(..., sensor = \"%s\").",
      paste(labels, collapse = ", "), labels[1], item$sensor$tied[2]))
  }
  type <- item$scale$type
  if (type == "int_10000") {
    msg <- "Values look like reflectance x 10,000. For indices such as EVI and SAVI, convert first: r / 10000."
    if (isTRUE(item$scale$offset == -0.1)) {
      msg <- "Almost all values are above 1000: the image seems to carry the +1000 offset of Sentinel-2 L2A (processing since 2022-01-25, including the reprocessed Collection 1). Convert to reflectance with (r - 1000) / 10000 before computing indices."
    } else if (isTRUE(item$sensor$sensor == "sentinel2")) {
      msg <- paste(msg, "Note: Sentinel-2 L2A images processed since 2022-01-25 have a -1000 offset [reflectance = (value - 1000) / 10000]; some providers already remove it, check yours.")
    }
    a[[length(a) + 1]] <- alert(id, msg, "info")
  }
  if (type == "landsat_c2") {
    a[[length(a) + 1]] <- alert(id, "Landsat Collection 2 values: convert to reflectance with r * 0.0000275 - 0.2 before computing indices.", "info")
  }
  if (type == "int_8bit") {
    a[[length(a) + 1]] <- alert(id, "Values from 0 to 255 suggest an 8-bit image (e.g. a color composite for display). Indices computed on it are not comparable to those computed on reflectance.")
  }
  if (isTRUE(item$dem$confidence == "medium")) {
    a[[length(a) + 1]] <- alert(id, sprintf(
      "I treated this raster as a likely digital elevation model (%s). Please confirm; if it is not, ignore the terrain suggestions.",
      item$dem$reason), "info")
  }
  bind_alerts(a)
}
