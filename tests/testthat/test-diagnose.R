test_that("in-memory Sentinel-2 raster", {
  d <- diagnose(fake_raster())
  expect_s3_class(d, "rsguide_diagnosis")
  r1 <- d$items$R1
  expect_equal(r1$n_layers, 6)
  expect_equal(r1$sensor$sensor, "sentinel2")
  expect_equal(r1$scale$type, "int_10000")
  expect_equal(r1$crs$epsg, 32718)
  tags <- d$contexts$SC1$tags
  expect_true(all(c("raster", "band:red", "band:nir", "band:swir2", "multispectral") %in% tags))
  expect_false("dem" %in% tags)
})

test_that("a DEM gets the dem tag", {
  d <- diagnose(fake_dem())
  expect_true(d$items$R1$dem$dem)
  expect_true("dem" %in% d$contexts$SC1$tags)
  expect_false(any(grepl("^band:", d$contexts$SC1$tags)))
  expect_equal(d$items$R1$scale$type, "elevation")
})

test_that("a lon/lat table becomes points and the overlap is checked", {
  d <- diagnose(fake_raster(), fake_points())
  expect_equal(d$items$T1$type, "table")
  expect_equal(d$items$T1$geometries, "points")
  expect_equal(d$items$T1$crs$epsg, 4326)
  expect_equal(d$overlaps$status, "full")
  expect_false(d$overlaps$same_crs)
  tags <- d$contexts[["SC1+T1"]]$tags
  expect_true(all(c("vector:points", "overlap", "crs_mismatch", "vector:labeled") %in% tags))
  expect_true(any(grepl("Different CRSs", d$alerts$message)))
})

test_that("points outside the raster are reported", {
  d <- diagnose(fake_raster(), fake_points(inside = FALSE))
  expect_equal(d$overlaps$status, "none")
  expect_false("overlap" %in% d$contexts[["SC1+T1"]]$tags)
})

test_that("sf polygons in the same CRS", {
  d <- diagnose(fake_raster(), fake_polygons())
  expect_equal(d$items$V1$geometries, "polygons")
  expect_equal(d$overlaps$status, "full")
  expect_true(d$overlaps$same_crs)
  expect_true("vector:polygons" %in% d$contexts[["SC1+V1"]]$tags)
})

test_that("coordinate columns with various names and decimal commas", {
  df <- data.frame(decimalLatitude = c("-7,6", "-7,7"), decimalLongitude = c("-72,6", "-72,7"))
  expect_equal(detect_coord_columns(df), c("decimalLongitude", "decimalLatitude"))
  d <- diagnose(df)
  expect_equal(d$items$T1$n_features, 2)

  expect_equal(detect_coord_columns(data.frame(X = 1, Y = 2)), c("X", "Y"))
  expect_null(detect_coord_columns(data.frame(a = 1, b = 2)))

  utm <- data.frame(x = c(700100, 700200), y = c(9150100, 9150200))
  d <- diagnose(utm)
  expect_false(d$items$T1$crs$defined)
  expect_true(any(grepl("look projected", d$alerts$message)))
  d <- diagnose(utm, table_crs = 32718)
  expect_equal(d$items$T1$crs$epsg, 32718)
})

test_that("a folder with several dates becomes a time series", {
  r <- fake_raster(c("red", "nir"))
  dates <- sprintf("2023%02d15", 1:3)
  rasters <- stats::setNames(lapply(1:3, function(i) r + i), paste0("jurua_", dates))
  folder <- folder_with_rasters(rasters)
  on.exit(unlink(folder, recursive = TRUE))

  d <- diagnose(folder)
  expect_length(d$items, 3)
  expect_length(d$series, 1)
  expect_equal(d$series[[1]]$n_dates, 3)
  tags <- d$contexts$S1$tags
  expect_true(all(c("time_series", "band:red", "band:nir") %in% tags))
  expect_false("long_series" %in% tags)

  old <- options(rsguide.min_dates_long_series = 3)
  on.exit(options(old), add = TRUE)
  expect_true("long_series" %in% diagnose(folder)$contexts$S1$tags)
})

test_that("Sentinel-2 bands in separate files form one scene", {
  base <- "T18LZQ_20230715T150721_"
  bands <- c("B02", "B03", "B04", "B08")
  rasters <- stats::setNames(
    lapply(seq_along(bands), function(i) fake_raster(bands[i], seed = i)),
    paste0(base, bands, "_10m"))
  folder <- folder_with_rasters(rasters)
  on.exit(unlink(folder, recursive = TRUE))

  d <- diagnose(folder)
  expect_length(d$scenes, 1)
  expect_length(d$scenes[[1]]$items, 4)
  expect_length(d$series, 0)
  expect_true("multispectral" %in% d$contexts$SC1$tags)
  expect_equal(d$scenes[[1]]$sensor, "sentinel2")
})

test_that("undated images of the same area raise an alert", {
  d <- diagnose(a = fake_raster(), b = fake_raster(seed = 9))
  expect_length(d$scenes, 2)
  expect_true(any(grepl("without an identified date", d$alerts$message)))
})

test_that("unrecognized layers and missing CRS raise alerts", {
  r <- fake_raster(c("lyr1", "lyr2", "lyr3", "lyr4"))
  d <- diagnose(r)
  expect_true(any(grepl("did not recognize the layer names", d$alerts$message)))
  expect_true("multispectral" %in% d$contexts$SC1$tags)

  terra::crs(r) <- ""
  d <- diagnose(r)
  expect_false(d$items$R1$crs$defined)
  expect_true(any(grepl("CRS", d$alerts$message)))
})

test_that("invalid inputs give clear errors", {
  expect_error(diagnose(), "at least one dataset")
  expect_error(diagnose(42), "don't know how to diagnose")
  expect_error(diagnose("does/not/exist.tif"), "not found")
})

test_that("vector and table files are read from disk", {
  folder <- tempfile("rsguide_")
  dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE))
  sf::st_write(fake_polygons(), file.path(folder, "plots.gpkg"), quiet = TRUE)
  utils::write.csv2(fake_points(), file.path(folder, "occurrences.csv"), row.names = FALSE)

  d <- diagnose(file.path(folder, "plots.gpkg"), file.path(folder, "occurrences.csv"))
  expect_equal(d$items$V1$name, "plots")
  expect_equal(d$items$T1$name, "occurrences")
  expect_equal(d$items$T1$n_features, 15)
})

test_that("print shows the diagnosis", {
  d <- diagnose(image = fake_raster(), fake_points())
  out <- capture.output(print(d))
  expect_true(any(grepl("Sentinel-2", out)))
  expect_true(any(grepl("overlap", out)))
  expect_true(any(grepl("Alerts", out)))
  capture.output(res <- withVisible(print(d)))
  expect_false(res$visible)
})
