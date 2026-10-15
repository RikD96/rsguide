test_that("print shows the short list of suggestions", {
  d <- diagnose(image = fake_raster(), fake_points())
  out <- capture.output(print(d))
  expect_true(any(grepl("Suggested analyses", out)))
  expect_true(any(grepl("[ndvi]", out, fixed = TRUE)))
  expect_false(any(grepl("Why:", out)))
  expect_true(any(grepl("summary()", out, fixed = TRUE)))
})

test_that("summary shows rationale, caveats and, optionally, code", {
  d <- diagnose(image = fake_raster(), fake_points())
  s <- summary(d)
  expect_s3_class(s, "summary.rsguide_diagnosis")
  out <- capture.output(print(s))
  expect_true(any(grepl("Why:", out)))
  expect_true(any(grepl("Caveats", out)))
  expect_true(any(grepl("Sentinel-2", out)))
  expect_false(any(grepl("ndvi <-", out)))

  with_code <- capture.output(print(summary(d, code = TRUE)))
  expect_true(any(grepl("ndvi <-", with_code)))
})

test_that("as.data.frame exports suggestions, items and alerts", {
  d <- diagnose(image = fake_raster(), fake_points())
  sug <- as.data.frame(d)
  expect_s3_class(sug, "data.frame")
  expect_true(all(c("analysis", "applies_to", "files", "caveats", "code") %in% names(sug)))
  expect_equal(nrow(sug), nrow(d$suggestions))
  expect_equal(sug$files[sug$id == "point_extraction"], "image; fake_points()")

  items <- as.data.frame(d, type = "items")
  expect_equal(items$id, c("R1", "T1"))
  expect_equal(items$sensor[1], "Sentinel-2 (MSI)")
  expect_equal(items$geometry[2], "points")
  expect_match(items$bands[1], "B4=red")

  expect_identical(as.data.frame(d, type = "alerts"), d$alerts)
  expect_error(as.data.frame(diagnose(fake_raster(), suggest = FALSE)), "no suggestions")
})

test_that("files read from disk appear by name in the export", {
  folder <- folder_with_rasters(list(scene_20230701 = fake_raster()))
  on.exit(unlink(folder, recursive = TRUE))
  sug <- as.data.frame(diagnose(folder))
  expect_true(all(sug$files == "scene_20230701.tif"))
})

test_that("a table without coordinates appears in the summary", {
  d <- diagnose(data.frame(a = 1:3, b = 4:6))
  expect_equal(nrow(d$suggestions), 0)
  expect_match(as.data.frame(d, type = "items")$description, "no coordinates")
  expect_output(print(summary(d)), "no coordinates")
  expect_output(print(d), "No analysis")
})
