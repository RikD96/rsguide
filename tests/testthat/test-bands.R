test_that("Sentinel-2 bands are recognized", {
  id <- identify_bands(c("B2", "B03", "B4", "B8", "B8A", "B11", "B12"))
  expect_equal(id$sensor, "sentinel2")
  expect_equal(id$confidence, "high")
  expect_equal(id$bands$group, c("blue", "green", "red", "nir", "nir", "swir1", "swir2"))
})

test_that("Sentinel-2 file names are recognized", {
  nm <- "T18LZQ_20230715T150721_B04_10m"
  id <- identify_bands(nm, texts = nm)
  expect_equal(id$sensor, "sentinel2")
  expect_equal(id$bands$band, "B4")
  expect_equal(id$bands$group, "red")
})

test_that("Landsat 8/9 and Landsat 4-7 are told apart", {
  l89 <- identify_bands(c("SR_B2", "SR_B3", "SR_B4", "SR_B5", "SR_B6", "SR_B7"))
  expect_equal(l89$sensor, "landsat89")
  expect_equal(l89$bands$group[4], "nir")

  l57 <- identify_bands(c("SR_B1", "SR_B2", "SR_B3", "SR_B4", "SR_B5", "SR_B7", "ST_B6"))
  expect_equal(l57$sensor, "landsat457")
  expect_equal(l57$bands$group[4], "nir")
})

test_that("ambiguous names give low confidence and the sensor can be forced", {
  amb <- identify_bands(c("SR_B2", "SR_B3", "SR_B4"))
  expect_equal(amb$confidence, "low")
  expect_length(amb$tied, 2)

  forced <- identify_bands(c("SR_B2", "SR_B3", "SR_B4"), sensor = "landsat457")
  expect_equal(forced$sensor, "landsat457")
  expect_equal(forced$confidence, "user")
  expect_equal(forced$bands$group, c("green", "red", "nir"))
  expect_error(identify_bands("B2", sensor = "modis"), "Unknown sensor")
})

test_that("generic and unknown names", {
  gen <- identify_bands(c("Blue", "green", "RED", "nir", "swir_1"))
  expect_equal(gen$sensor, "generic")
  expect_equal(gen$bands$group, c("blue", "green", "red", "nir", "swir1"))

  pt <- identify_bands(c("azul", "vermelho", "ivp"))
  expect_equal(pt$bands$group, c("blue", "red", "nir"))

  none <- identify_bands(c("lyr.1", "lyr.2"))
  expect_true(is.na(none$sensor))
  expect_true(all(is.na(none$bands$group)))
})
