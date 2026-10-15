test_that("condições com &, | e ! são avaliadas", {
  expect_true(avaliar_condicao("a & b", c("a", "b", "c")))
  expect_false(avaliar_condicao("a & b", c("a")))
  expect_true(avaliar_condicao("a & b | c", c("c")))
  expect_false(avaliar_condicao("a & !b", c("a", "b")))
  expect_true(avaliar_condicao(" a&!b ", c("a")))
})

test_that("a tabela de regras do pacote é válida e tem exemplos", {
  regras <- regras_rsguia()
  expect_true(all(COLUNAS_REGRAS %in% names(regras)))
  expect_false(anyDuplicated(regras$id) > 0)
  exemplos <- system.file("exemplos", paste0(regras$id, ".R"), package = "rsguia")
  expect_true(all(nzchar(exemplos)))
})

test_that("regras com problemas são apontadas", {
  regras <- regras_rsguia()
  expect_error(validar_regras(regras[, -1]), "Faltam colunas")
  expect_error(validar_regras(rbind(regras, regras[1, ])), "repetidos")
  ruim <- regras[1, ]
  ruim$id <- "x"
  ruim$condicao <- "banda:vermelha & banda:nir"
  expect_warning(validar_regras(rbind(regras, ruim)), "desconhecidas")
})

test_that("sugestões para imagem Sentinel-2", {
  d <- diagnosticar(raster_falso())
  ids <- unique(d$sugestoes$id)
  expect_true(all(c("ndvi", "evi", "savi", "ndwi", "mndwi", "ndmi", "nbr",
                    "class_sup", "class_nsup") %in% ids))
  expect_false(any(c("ndre", "declividade", "extracao", "mudanca") %in% ids))
  expect_match(d$sugestoes$codigo[d$sugestoes$id == "ndvi"], "img[[\"B8\"]]", fixed = TRUE)
  expect_match(d$sugestoes$codigo[d$sugestoes$id == "ndvi"], "img / 10000", fixed = TRUE)
})

test_that("sugestões para MDE", {
  d <- diagnosticar(mde_falso())
  expect_setequal(d$sugestoes$id, c("declividade", "orientacao", "bacias"))
})

test_that("raster + pontos sugere extração sem repetir os índices", {
  d <- diagnosticar(raster_falso(), pontos_falsos())
  s <- d$sugestoes
  expect_equal(s$contexto[s$id == "extracao"], "C1+T1")
  expect_equal(s$contexto[s$id == "ndvi"], "C1")
  expect_false("zonal" %in% s$id)
})

test_that("raster + polígonos sugere estatística zonal", {
  d <- diagnosticar(raster_falso(), poligonos_falsos())
  expect_true("zonal" %in% d$sugestoes$id)
  expect_false("extracao" %in% d$sugestoes$id)
})

test_that("pontos fora do raster não geram extração", {
  d <- diagnosticar(raster_falso(), pontos_falsos(dentro = FALSE))
  expect_false("extracao" %in% d$sugestoes$id)
})

test_that("regras próprias e sugerir = FALSE", {
  d <- diagnosticar(raster_falso(), sugerir = FALSE)
  expect_null(d$sugestoes)

  nova <- data.frame(id = "gndvi", analise = "GNDVI", categoria = "Teste",
                     condicao = "banda:green & banda:nir", justificativa = "j",
                     cuidados = "a | b", pacotes = "terra")
  d <- sugerir_analises(d, regras = nova)
  expect_equal(d$sugestoes$id, "gndvi")
  expect_true(is.na(d$sugestoes$codigo))
  expect_error(sugerir_analises(list()), "diagnosticar")
})

test_that("ver_codigo mostra o código e valida o id", {
  d <- diagnosticar(raster_falso())
  saida <- capture.output(cod <- ver_codigo(d, "ndvi"))
  expect_true(any(grepl("ndvi <-", saida)))
  expect_length(cod, 1)
  expect_error(ver_codigo(d, "declividade"), "não sugerida")
})

test_that("o código gerado para cada sugestão roda sem erros", {
  pasta <- tempfile("rsguia_")
  dir.create(pasta)
  on.exit(unlink(pasta, recursive = TRUE))
  r <- raster_falso(c("B2", "B3", "B4", "B5", "B8", "B11", "B12"))
  terra::writeRaster(r, file.path(pasta, "s2_20230701.tif"))
  terra::writeRaster(r * 0.9, file.path(pasta, "s2_20240701.tif"), datatype = "INT2U")
  terra::writeRaster(mde_falso(), file.path(pasta, "mde.tif"))
  utils::write.csv2(pontos_falsos(), file.path(pasta, "parcelas.csv"), row.names = FALSE)
  sf::st_write(poligonos_falsos(), file.path(pasta, "talhoes.gpkg"), quiet = TRUE)
  terra::writeRaster(mapa_classes_falso(), file.path(pasta, "mapbiomas.tif"), datatype = "INT1U")

  op <- options(rsguia.min_datas_serie_longa = 2)
  on.exit(options(op), add = TRUE)
  d <- diagnosticar(pasta)
  s <- d$sugestoes
  expect_true(all(c("ndvi", "ndre", "mudanca", "tendencia", "declividade", "bacias",
                    "extracao", "zonal", "class_sup_amostras", "metricas_paisagem") %in% s$id))

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  executaveis <- s[s$id != "class_sup", , drop = FALSE]  # precisa de amostras do usuário
  if (!requireNamespace("randomForest", quietly = TRUE)) executaveis <- executaveis[executaveis$id != "class_sup_amostras", ]
  if (!requireNamespace("landscapemetrics", quietly = TRUE)) executaveis <- executaveis[executaveis$id != "metricas_paisagem", ]
  for (k in seq_len(nrow(executaveis))) {
    expect_no_error(
      utils::capture.output(eval(parse(text = executaveis$codigo[k]), envir = new.env())),
      message = paste(executaveis$id[k], executaveis$contexto[k])
    )
  }
})

test_that("mapa de classes sugere métricas de paisagem", {
  d <- diagnosticar(mapa_classes_falso())
  expect_equal(d$itens$R1$escala$tipo, "categorica")
  expect_true("metricas_paisagem" %in% d$sugestoes$id)
  expect_false("declividade" %in% d$sugestoes$id)
})

test_that("pontos com classes sugerem classificação com as amostras do usuário", {
  d <- diagnosticar(raster_falso(), pontos_falsos())
  s <- d$sugestoes
  expect_equal(s$contexto[s$id == "class_sup_amostras"], "C1+T1")
  expect_match(s$codigo[s$id == "class_sup_amostras"], "amostras[[\"especie\"]]", fixed = TRUE)

  sem_classes <- pontos_falsos()[, c("lon", "lat")]
  expect_false("class_sup_amostras" %in% diagnosticar(raster_falso(), sem_classes)$sugestoes$id)
})

test_that("regras em CSV do Excel (ponto e vírgula, latin1) são lidas", {
  arq <- tempfile(fileext = ".csv")
  on.exit(unlink(arq))
  regras <- regras_rsguia()[1:2, ]
  con <- file(arq, open = "w", encoding = "latin1")
  utils::write.table(regras, con, sep = ";", row.names = FALSE, qmethod = "double")
  close(con)
  lidas <- regras_rsguia(arq)
  expect_equal(lidas$analise, regras$analise)
  expect_equal(lidas$cuidados, regras$cuidados)
})

test_that("regra própria com modelo de código próprio", {
  modelo <- tempfile(fileext = ".R")
  on.exit(unlink(modelo))
  writeLines(c("{carregar_raster:img}", "{escala}", "gndvi <- (img[[\"{nir}\"]] - img[[\"{green}\"]]) / (img[[\"{nir}\"]] + img[[\"{green}\"]])"), modelo)
  nova <- data.frame(id = "gndvi", analise = "GNDVI", categoria = "Teste",
                     condicao = "banda:green & banda:nir", justificativa = "j",
                     cuidados = "a", pacotes = "terra", exemplo = modelo)
  d <- diagnosticar(raster_falso(), regras = nova)
  expect_match(d$sugestoes$codigo, "img[[\"B8\"]] - img[[\"B3\"]]", fixed = TRUE)
})
