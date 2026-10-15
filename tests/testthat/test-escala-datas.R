bandas_s2 <- function(n) identificar_bandas(c("B2", "B3", "B4", "B8", "B11", "B12")[seq_len(n)])$bandas

test_that("escalas de reflectância são detectadas", {
  v01 <- matrix(stats::runif(400, 0.01, 0.6), ncol = 4)
  expect_equal(detectar_escala(v01, bandas_s2(4), "sentinel2")$tipo, "reflectancia_0_1")

  v10k <- round(v01 * 10000)
  expect_equal(detectar_escala(v10k, bandas_s2(4), "sentinel2")$tipo, "inteiro_10000")

  vls <- round((v01 + 0.2) / 2.75e-5)
  b_ls <- identificar_bandas(c("SR_B2", "SR_B3", "SR_B4", "SR_B5"))$bandas
  expect_equal(detectar_escala(vls, b_ls, "landsat89")$tipo, "landsat_c2")

  v8 <- matrix(sample(0:255, 400, TRUE), ncol = 4)
  expect_equal(detectar_escala(v8, bandas_s2(4), "sentinel2")$tipo, "inteiro_8bits")
})

test_that("índices e mapas de classes são detectados", {
  sem_banda <- identificar_bandas("camada")$bandas
  ndvi <- matrix(stats::runif(100, -0.8, 0.9), ncol = 1)
  expect_equal(detectar_escala(ndvi, sem_banda, NA)$tipo, "indice")
  classes <- matrix(sample(1:6, 100, TRUE), ncol = 1)
  expect_equal(detectar_escala(classes, sem_banda, NA)$tipo, "categorica")
})

test_that("MDE é detectado pelo nome ou pelos valores", {
  sem_banda <- identificar_bandas("srtm_jurua")$bandas
  v <- matrix(stats::runif(500, 150, 400), ncol = 1)
  expect_equal(detectar_mde("srtm_jurua", character(), sem_banda, v)$confianca, "alta")

  anon <- identificar_bandas("camada")$bandas
  expect_equal(detectar_mde("camada", character(), anon, v)$confianca, "média")

  ndvi <- matrix(stats::runif(500, -1, 1), ncol = 1)
  expect_false(detectar_mde("srtm", character(), anon, ndvi)$mde)
  expect_false(detectar_mde("B4", character(), bandas_s2(1), v)$mde)
})

test_that("datas são extraídas de nomes", {
  x <- c("S2A_MSIL2A_20230715T150721_N0509", "LC09_L2SP_003067_20230801_20230803_02_T1",
         "ndvi_2021-03-05", "MOD13Q1.A2020161.h11v09", "sem_data", "20230230")
  d <- extrair_data(x)
  expect_equal(d[1:4], as.Date(c("2023-07-15", "2023-08-01", "2021-03-05", "2020-06-09")))
  expect_true(all(is.na(d[5:6])))
})
