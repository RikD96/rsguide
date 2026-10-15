test_that("print mostra a lista curta de sugestões", {
  d <- diagnosticar(imagem = raster_falso(), pontos_falsos())
  saida <- capture.output(print(d))
  expect_true(any(grepl("Análises sugeridas", saida)))
  expect_true(any(grepl("[ndvi]", saida, fixed = TRUE)))
  expect_false(any(grepl("Por quê", saida)))
  expect_true(any(grepl("summary()", saida, fixed = TRUE)))
})

test_that("summary mostra justificativas, cuidados e, opcionalmente, código", {
  d <- diagnosticar(imagem = raster_falso(), pontos_falsos())
  s <- summary(d)
  expect_s3_class(s, "summary.rsguia_diagnostico")
  saida <- capture.output(print(s))
  expect_true(any(grepl("Por quê", saida)))
  expect_true(any(grepl("Cuidados", saida)))
  expect_true(any(grepl("Sentinel-2", saida)))
  expect_false(any(grepl("ndvi <-", saida)))

  com_codigo <- capture.output(print(summary(d, codigo = TRUE)))
  expect_true(any(grepl("ndvi <-", com_codigo)))
})

test_that("as.data.frame exporta sugestões, itens e alertas", {
  d <- diagnosticar(imagem = raster_falso(), pontos_falsos())
  sug <- as.data.frame(d)
  expect_s3_class(sug, "data.frame")
  expect_true(all(c("analise", "aplica_a", "arquivos", "cuidados", "codigo") %in% names(sug)))
  expect_equal(nrow(sug), nrow(d$sugestoes))
  expect_equal(sug$arquivos[sug$id == "extracao"], "imagem; pontos_falsos()")

  itens <- as.data.frame(d, tipo = "itens")
  expect_equal(itens$id, c("R1", "T1"))
  expect_equal(itens$sensor[1], "Sentinel-2 (MSI)")
  expect_equal(itens$geometria[2], "pontos")
  expect_match(itens$bandas[1], "B4=red")

  expect_identical(as.data.frame(d, tipo = "alertas"), d$alertas)
  expect_error(as.data.frame(diagnosticar(raster_falso(), sugerir = FALSE)), "sugest")
})

test_that("arquivos do disco aparecem pelo nome na exportação", {
  pasta <- pasta_com_rasters(list(cena_20230701 = raster_falso()))
  on.exit(unlink(pasta, recursive = TRUE))
  sug <- as.data.frame(diagnosticar(pasta))
  expect_true(all(sug$arquivos == "cena_20230701.tif"))
})

test_that("tabela sem coordenadas aparece no resumo", {
  d <- diagnosticar(data.frame(a = 1:3, b = 4:6))
  expect_equal(nrow(d$sugestoes), 0)
  expect_match(as.data.frame(d, tipo = "itens")$descricao, "sem coordenadas")
  expect_output(print(summary(d)), "sem coordenadas")
  expect_output(print(d), "Nenhuma análise")
})
