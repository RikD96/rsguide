test_that("bandas do Sentinel-2 são reconhecidas", {
  id <- identificar_bandas(c("B2", "B03", "B4", "B8", "B8A", "B11", "B12"))
  expect_equal(id$sensor, "sentinel2")
  expect_equal(id$confianca, "alta")
  expect_equal(id$bandas$grupo, c("blue", "green", "red", "nir", "nir", "swir1", "swir2"))
})

test_that("nomes de arquivo do Sentinel-2 são reconhecidos", {
  nm <- "T18LZQ_20230715T150721_B04_10m"
  id <- identificar_bandas(nm, textos = nm)
  expect_equal(id$sensor, "sentinel2")
  expect_equal(id$bandas$banda, "B4")
  expect_equal(id$bandas$grupo, "red")
})

test_that("Landsat 8/9 e Landsat 4-7 são distinguidos", {
  l89 <- identificar_bandas(c("SR_B2", "SR_B3", "SR_B4", "SR_B5", "SR_B6", "SR_B7"))
  expect_equal(l89$sensor, "landsat89")
  expect_equal(l89$bandas$grupo[4], "nir")

  l57 <- identificar_bandas(c("SR_B1", "SR_B2", "SR_B3", "SR_B4", "SR_B5", "SR_B7", "ST_B6"))
  expect_equal(l57$sensor, "landsat457")
  expect_equal(l57$bandas$grupo[4], "nir")
})

test_that("nomes ambíguos geram confiança baixa e podem ser forçados", {
  amb <- identificar_bandas(c("SR_B2", "SR_B3", "SR_B4"))
  expect_equal(amb$confianca, "baixa")
  expect_length(amb$empatados, 2)

  forc <- identificar_bandas(c("SR_B2", "SR_B3", "SR_B4"), sensor = "landsat457")
  expect_equal(forc$sensor, "landsat457")
  expect_equal(forc$bandas$grupo, c("green", "red", "nir"))
  expect_error(identificar_bandas("B2", sensor = "modis"), "Sensor desconhecido")
})

test_that("nomes genéricos e desconhecidos", {
  gen <- identificar_bandas(c("Blue", "green", "RED", "nir", "swir_1"))
  expect_equal(gen$sensor, "generico")
  expect_equal(gen$bandas$grupo, c("blue", "green", "red", "nir", "swir1"))

  nada <- identificar_bandas(c("lyr.1", "lyr.2"))
  expect_true(is.na(nada$sensor))
  expect_true(all(is.na(nada$bandas$grupo)))
})
