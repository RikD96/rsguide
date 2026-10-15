test_that("conditions with &, | and ! are evaluated", {
  expect_true(eval_condition("a & b", c("a", "b", "c")))
  expect_false(eval_condition("a & b", c("a")))
  expect_true(eval_condition("a & b | c", c("c")))
  expect_false(eval_condition("a & !b", c("a", "b")))
  expect_true(eval_condition(" a&!b ", c("a")))
})

test_that("the package rules table is valid and every rule has a template", {
  rules <- rsguide_rules()
  expect_true(all(RULE_COLUMNS %in% names(rules)))
  expect_false(anyDuplicated(rules$id) > 0)
  templates <- system.file("templates", paste0(rules$id, ".R"), package = "rsguide")
  expect_true(all(nzchar(templates)))
})

test_that("problems in the rules are reported", {
  rules <- rsguide_rules()
  expect_error(validate_rules(rules[, -1]), "Columns missing")
  expect_error(validate_rules(rbind(rules, rules[1, ])), "Duplicated ids")
  bad <- rules[1, ]
  bad$id <- "x"
  bad$condition <- "band:reed & band:nir"
  expect_warning(validate_rules(rbind(rules, bad)), "Unknown tags")
})

test_that("suggestions for a Sentinel-2 image", {
  d <- diagnose(fake_raster())
  ids <- unique(d$suggestions$id)
  expect_true(all(c("ndvi", "evi", "savi", "ndwi", "mndwi", "ndmi", "nbr",
                    "supervised_class", "unsupervised_class") %in% ids))
  expect_false(any(c("ndre", "slope", "point_extraction", "change_detection") %in% ids))
  expect_match(d$suggestions$code[d$suggestions$id == "ndvi"], "img[[\"B8\"]]", fixed = TRUE)
  expect_match(d$suggestions$code[d$suggestions$id == "ndvi"], "img / 10000", fixed = TRUE)
})

test_that("suggestions for a DEM", {
  d <- diagnose(fake_dem())
  expect_setequal(d$suggestions$id, c("slope", "aspect", "watersheds"))
})

test_that("raster + points suggests extraction without repeating the indices", {
  d <- diagnose(fake_raster(), fake_points())
  s <- d$suggestions
  expect_equal(s$context[s$id == "point_extraction"], "SC1+T1")
  expect_equal(s$context[s$id == "ndvi"], "SC1")
  expect_false("zonal_stats" %in% s$id)
})

test_that("raster + polygons suggests zonal statistics", {
  d <- diagnose(fake_raster(), fake_polygons())
  expect_true("zonal_stats" %in% d$suggestions$id)
  expect_false("point_extraction" %in% d$suggestions$id)
})

test_that("points outside the raster do not trigger extraction", {
  d <- diagnose(fake_raster(), fake_points(inside = FALSE))
  expect_false("point_extraction" %in% d$suggestions$id)
})

test_that("a class map suggests landscape metrics", {
  d <- diagnose(fake_class_map())
  expect_equal(d$items$R1$scale$type, "categorical")
  expect_true("landscape_metrics" %in% d$suggestions$id)
  expect_false("slope" %in% d$suggestions$id)
})

test_that("labeled points suggest classification with the user's samples", {
  d <- diagnose(fake_raster(), fake_points())
  s <- d$suggestions
  expect_equal(s$context[s$id == "supervised_class_samples"], "SC1+T1")
  expect_match(s$code[s$id == "supervised_class_samples"], "samples[[\"species\"]]", fixed = TRUE)

  unlabeled <- fake_points()[, c("lon", "lat")]
  expect_false("supervised_class_samples" %in% diagnose(fake_raster(), unlabeled)$suggestions$id)
})

test_that("custom rules and suggest = FALSE", {
  d <- diagnose(fake_raster(), suggest = FALSE)
  expect_null(d$suggestions)

  new_rule <- data.frame(id = "gndvi", analysis = "GNDVI", category = "Test",
                         condition = "band:green & band:nir", rationale = "r",
                         caveats = "a | b", packages = "terra")
  d <- suggest_analyses(d, rules = new_rule)
  expect_equal(d$suggestions$id, "gndvi")
  expect_true(is.na(d$suggestions$code))
  expect_error(suggest_analyses(list()), "diagnose")
})

test_that("custom rule with its own template", {
  template <- tempfile(fileext = ".R")
  on.exit(unlink(template))
  writeLines(c("{load_raster:img}", "{scale}",
               "gndvi <- (img[[\"{nir}\"]] - img[[\"{green}\"]]) / (img[[\"{nir}\"]] + img[[\"{green}\"]])"),
             template)
  new_rule <- data.frame(id = "gndvi", analysis = "GNDVI", category = "Test",
                         condition = "band:green & band:nir", rationale = "r",
                         caveats = "a", packages = "terra", template = template)
  d <- diagnose(fake_raster(), rules = new_rule)
  expect_match(d$suggestions$code, "img[[\"B8\"]] - img[[\"B3\"]]", fixed = TRUE)
})

test_that("rules saved by Excel (semicolon, latin1) are read", {
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file))
  rules <- rsguide_rules()[1:2, ]
  rules$analysis[1] <- "Índice de vegetação"
  con <- file(file, open = "w", encoding = "latin1")
  utils::write.table(rules, con, sep = ";", row.names = FALSE, qmethod = "double")
  close(con)
  read_back <- rsguide_rules(file)
  expect_equal(read_back$analysis, rules$analysis)
  expect_equal(read_back$caveats, rules$caveats)
})

test_that("show_code prints the code and checks the id", {
  d <- diagnose(fake_raster())
  out <- capture.output(code <- show_code(d, "ndvi"))
  expect_true(any(grepl("ndvi <-", out)))
  expect_length(code, 1)
  expect_error(show_code(d, "slope"), "not suggested")
})

test_that("the generated code for every suggestion runs without errors", {
  folder <- tempfile("rsguide_")
  dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE))
  r <- fake_raster(c("B2", "B3", "B4", "B5", "B8", "B11", "B12"))
  terra::writeRaster(r, file.path(folder, "s2_20230701.tif"))
  terra::writeRaster(r * 0.9, file.path(folder, "s2_20240701.tif"), datatype = "INT2U")
  terra::writeRaster(fake_dem(), file.path(folder, "dem.tif"))
  utils::write.csv2(fake_points(), file.path(folder, "plots.csv"), row.names = FALSE)
  sf::st_write(fake_polygons(), file.path(folder, "fields.gpkg"), quiet = TRUE)
  terra::writeRaster(fake_class_map(), file.path(folder, "mapbiomas.tif"), datatype = "INT1U")

  old <- options(rsguide.min_dates_long_series = 2)
  on.exit(options(old), add = TRUE)
  d <- diagnose(folder)
  s <- d$suggestions
  expect_true(all(c("ndvi", "ndre", "change_detection", "trend", "slope", "watersheds",
                    "point_extraction", "zonal_stats", "supervised_class_samples",
                    "landscape_metrics") %in% s$id))

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  runnable <- s[s$id != "supervised_class", , drop = FALSE]  # needs the user's samples
  if (!requireNamespace("randomForest", quietly = TRUE)) runnable <- runnable[runnable$id != "supervised_class_samples", ]
  if (!requireNamespace("landscapemetrics", quietly = TRUE)) runnable <- runnable[runnable$id != "landscape_metrics", ]
  for (k in seq_len(nrow(runnable))) {
    expect_no_error(
      utils::capture.output(eval(parse(text = runnable$code[k]), envir = new.env())),
      message = paste(runnable$id[k], runnable$context[k])
    )
  }
})
