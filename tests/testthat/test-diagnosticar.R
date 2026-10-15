test_that("raster Sentinel-2 em memória", {
  d <- diagnosticar(raster_falso())
  expect_s3_class(d, "rsguia_diagnostico")
  r1 <- d$itens$R1
  expect_equal(r1$n_camadas, 6)
  expect_equal(r1$sensor$sensor, "sentinel2")
  expect_equal(r1$escala$tipo, "inteiro_10000")
  expect_equal(r1$crs$epsg, 32718)
  tags <- d$contextos$C1$tags
  expect_true(all(c("raster", "banda:red", "banda:nir", "banda:swir2", "multiespectral") %in% tags))
  expect_false("mde" %in% tags)
})

test_that("MDE gera a etiqueta mde", {
  d <- diagnosticar(mde_falso())
  expect_true(d$itens$R1$mde$mde)
  expect_true("mde" %in% d$contextos$C1$tags)
  expect_equal(d$itens$R1$escala$tipo, "elevacao")
})

test_that("tabela com lon/lat vira pontos e a sobreposição é verificada", {
  d <- diagnosticar(raster_falso(), pontos_falsos())
  expect_equal(d$itens$T1$tipo, "tabela")
  expect_equal(d$itens$T1$geometrias, "pontos")
  expect_equal(d$itens$T1$crs$epsg, 4326)
  expect_equal(d$sobreposicoes$status, "total")
  expect_false(d$sobreposicoes$crs_igual)
  tags <- d$contextos[["C1+T1"]]$tags
  expect_true(all(c("vetor:pontos", "sobreposicao", "crs_diferente", "vetor:rotulado") %in% tags))
  expect_true(any(grepl("CRS diferentes", d$alertas$mensagem)))
})

test_that("pontos fora do raster são apontados", {
  d <- diagnosticar(raster_falso(), pontos_falsos(dentro = FALSE))
  expect_equal(d$sobreposicoes$status, "nenhuma")
  expect_false("sobreposicao" %in% d$contextos[["C1+T1"]]$tags)
})

test_that("polígonos sf no mesmo CRS", {
  d <- diagnosticar(raster_falso(), poligonos_falsos())
  expect_equal(d$itens$V1$geometrias, "poligonos")
  expect_equal(d$sobreposicoes$status, "total")
  expect_true(d$sobreposicoes$crs_igual)
  expect_true("vetor:poligonos" %in% d$contextos[["C1+V1"]]$tags)
})

test_that("colunas de coordenadas com nomes variados e vírgula decimal", {
  df <- data.frame(decimalLatitude = c("-7,6", "-7,7"), decimalLongitude = c("-72,6", "-72,7"))
  expect_equal(detectar_colunas_coord(df), c("decimalLongitude", "decimalLatitude"))
  d <- diagnosticar(df)
  expect_equal(d$itens$T1$n_feicoes, 2)

  expect_equal(detectar_colunas_coord(data.frame(X = 1, Y = 2)), c("X", "Y"))
  expect_null(detectar_colunas_coord(data.frame(a = 1, b = 2)))

  utm <- data.frame(x = c(700100, 700200), y = c(9150100, 9150200))
  d <- diagnosticar(utm)
  expect_false(d$itens$T1$crs$definido)
  expect_true(any(grepl("projetadas", d$alertas$mensagem)))
  d <- diagnosticar(utm, crs_tabela = 32718)
  expect_equal(d$itens$T1$crs$epsg, 32718)
})

test_that("pasta com várias datas vira série temporal", {
  r <- raster_falso(c("red", "nir"))
  datas <- sprintf("2023%02d15", 1:3)
  lista <- stats::setNames(lapply(1:3, function(i) r + i), paste0("jurua_", datas))
  pasta <- pasta_com_rasters(lista)
  on.exit(unlink(pasta, recursive = TRUE))

  d <- diagnosticar(pasta)
  expect_length(d$itens, 3)
  expect_length(d$series, 1)
  expect_equal(d$series[[1]]$n_datas, 3)
  tags <- d$contextos$S1$tags
  expect_true(all(c("serie_temporal", "banda:red", "banda:nir") %in% tags))
  expect_false("serie_longa" %in% tags)

  withr_opcao <- options(rsguia.min_datas_serie_longa = 3)
  on.exit(options(withr_opcao), add = TRUE)
  expect_true("serie_longa" %in% diagnosticar(pasta)$contextos$S1$tags)
})

test_that("bandas do Sentinel-2 em arquivos separados formam uma cena", {
  base <- "T18LZQ_20230715T150721_"
  bandas <- c("B02", "B03", "B04", "B08")
  lista <- stats::setNames(
    lapply(seq_along(bandas), function(i) raster_falso(bandas[i], semente = i)),
    paste0(base, bandas, "_10m"))
  pasta <- pasta_com_rasters(lista)
  on.exit(unlink(pasta, recursive = TRUE))

  d <- diagnosticar(pasta)
  expect_length(d$cenas, 1)
  expect_length(d$cenas[[1]]$itens, 4)
  expect_length(d$series, 0)
  expect_true("multiespectral" %in% d$contextos$C1$tags)
  expect_equal(d$cenas[[1]]$sensor, "sentinel2")
})

test_that("imagens da mesma área sem data geram alerta", {
  d <- diagnosticar(a = raster_falso(), b = raster_falso(semente = 9))
  expect_length(d$cenas, 2)
  expect_true(any(grepl("sem data", d$alertas$mensagem)))
})

test_that("camadas não reconhecidas e CRS ausente geram alertas", {
  r <- raster_falso(c("lyr1", "lyr2", "lyr3", "lyr4"))
  d <- diagnosticar(r)
  expect_true(any(grepl("Não reconheci", d$alertas$mensagem)))
  expect_true("multiespectral" %in% d$contextos$C1$tags)

  terra::crs(r) <- ""
  d <- diagnosticar(r)
  expect_false(d$itens$R1$crs$definido)
  expect_true(any(grepl("CRS", d$alertas$mensagem)))
})

test_that("entradas inválidas dão erro claro", {
  expect_error(diagnosticar(), "ao menos um dado")
  expect_error(diagnosticar(42), "Não sei diagnosticar")
  expect_error(diagnosticar("nao/existe.tif"), "não encontrado")
})

test_that("arquivos de vetor e tabela são lidos do disco", {
  pasta <- tempfile("rsguia_")
  dir.create(pasta)
  on.exit(unlink(pasta, recursive = TRUE))
  sf::st_write(poligonos_falsos(), file.path(pasta, "parcelas.gpkg"), quiet = TRUE)
  utils::write.csv2(pontos_falsos(), file.path(pasta, "ocorrencias.csv"), row.names = FALSE)

  d <- diagnosticar(file.path(pasta, "parcelas.gpkg"), file.path(pasta, "ocorrencias.csv"))
  expect_equal(d$itens$V1$nome, "parcelas")
  expect_equal(d$itens$T1$nome, "ocorrencias")
  expect_equal(d$itens$T1$n_feicoes, 15)
})

test_that("print mostra o diagnóstico em português", {
  d <- diagnosticar(imagem = raster_falso(), pontos_falsos())
  saida <- capture.output(print(d))
  expect_true(any(grepl("Sentinel-2", saida)))
  expect_true(any(grepl("Sobreposi", saida)))
  expect_true(any(grepl("Alertas", saida)))
  expect_invisible(print(d))
})
