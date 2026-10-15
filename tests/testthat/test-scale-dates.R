s2_bands <- function(n) identify_bands(c("B2", "B3", "B4", "B8", "B11", "B12")[seq_len(n)])$bands

test_that("reflectance scales are detected", {
  v01 <- matrix(stats::runif(400, 0.01, 0.6), ncol = 4)
  expect_equal(detect_scale(v01, s2_bands(4), "sentinel2")$type, "reflectance_0_1")

  v10k <- round(v01 * 10000)
  expect_equal(detect_scale(v10k, s2_bands(4), "sentinel2")$type, "int_10000")

  with_offset <- detect_scale(round(v01 * 10000) + 1000, s2_bands(4), "sentinel2")
  expect_equal(with_offset$type, "int_10000")
  expect_equal(with_offset$offset, -0.1)

  vls <- round((v01 + 0.2) / 2.75e-5)
  b_ls <- identify_bands(c("SR_B2", "SR_B3", "SR_B4", "SR_B5"))$bands
  expect_equal(detect_scale(vls, b_ls, "landsat89")$type, "landsat_c2")

  v8 <- matrix(sample(0:255, 400, TRUE), ncol = 4)
  expect_equal(detect_scale(v8, s2_bands(4), "sentinel2")$type, "int_8bit")
})

test_that("indices and class maps are detected", {
  no_band <- identify_bands("layer")$bands
  ndvi <- matrix(stats::runif(100, -0.8, 0.9), ncol = 1)
  expect_equal(detect_scale(ndvi, no_band, NA)$type, "index")
  classes <- matrix(sample(1:6, 100, TRUE), ncol = 1)
  expect_equal(detect_scale(classes, no_band, NA)$type, "categorical")
})

test_that("DEMs are detected by name or by values", {
  no_band <- identify_bands("srtm_jurua")$bands
  v <- matrix(stats::runif(500, 150, 400), ncol = 1)
  expect_equal(detect_dem("srtm_jurua", character(), no_band, v)$confidence, "high")

  anon <- identify_bands("layer")$bands
  expect_equal(detect_dem("layer", character(), anon, v)$confidence, "medium")

  ndvi <- matrix(stats::runif(500, -1, 1), ncol = 1)
  expect_false(detect_dem("srtm", character(), anon, ndvi)$dem)
  expect_false(detect_dem("B4", character(), s2_bands(1), v)$dem)
})

test_that("dates are extracted from names", {
  x <- c("S2A_MSIL2A_20230715T150721_N0509", "LC09_L2SP_003067_20230801_20230803_02_T1",
         "ndvi_2021-03-05", "MOD13Q1.A2020161.h11v09", "no_date", "20230230")
  d <- extract_date(x)
  expect_equal(d[1:4], as.Date(c("2023-07-15", "2023-08-01", "2021-03-05", "2020-06-09")))
  expect_true(all(is.na(d[5:6])))
})
