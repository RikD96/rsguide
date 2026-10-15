# Montagem dos exemplos de código ---------------------------------------------
#
# Os modelos ficam em inst/exemplos/<id>.R e usam marcadores entre chaves:
#   {carregar_raster:img}   linhas que criam o objeto `img` com o raster
#   {carregar_vetor:pontos} linhas que criam o objeto `pontos` (sf)
#   {carregar_serie:imgs}   linhas que criam a lista `imgs`, uma imagem por data
#   {escala}                linha que converte `img` para reflectância 0-1
#   {conversao}             a mesma conversão como expressão de `x`
#   {indice_expr}, {indice_nome}  NDVI (se houver vermelho e NIR) ou 1ª camada
#   {datas}                 vetor de datas da série
#   {blue}, {green}, {red}, {rededge}, {nir}, {swir1}, {swir2}...  nomes das camadas

ler_modelo <- function(regra) {
  arquivo <- NA_character_
  if ("exemplo" %in% names(regra) && !is.na(regra$exemplo)) {
    arquivo <- regra$exemplo
    if (!file.exists(arquivo)) arquivo <- system.file("exemplos", arquivo, package = "rsguia")
  } else {
    arquivo <- system.file("exemplos", paste0(regra$id, ".R"), package = "rsguia")
  }
  if (!nzchar(arquivo) || !file.exists(arquivo)) return(NA_character_)
  paste(readLines(arquivo, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

texto_r <- function(x) encodeString(x, quote = "\"")

montar_codigo <- function(regra, cx, diag) {
  modelo <- ler_modelo(regra)
  if (is.na(modelo)) return(NA_character_)

  partes <- strsplit(cx$id, "+", fixed = TRUE)[[1]]
  por_id <- function(lista, ids) {
    achados <- Filter(function(x) x$id %in% ids, lista)
    if (length(achados)) achados[[1]] else NULL
  }
  serie <- por_id(diag$series, partes)
  cena <- por_id(diag$cenas, partes)
  if (is.null(cena) && !is.null(serie)) cena <- por_id(diag$cenas, serie$cenas[1])
  vetor <- diag$itens[intersect(partes, names(diag$itens))]
  vetor <- Filter(function(i) i$tipo != "raster", vetor)
  vetor <- if (length(vetor)) vetor[[1]] else NULL

  substituir_bloco <- function(txt, marcador, gerar) {
    padrao <- paste0("\\{", marcador, ":([A-Za-z_.][A-Za-z0-9_.]*)\\}")
    while (grepl(padrao, txt)) {
      m <- regmatches(txt, regexec(padrao, txt))[[1]]
      txt <- sub(m[1], gerar(m[2]), txt, fixed = TRUE)
    }
    txt
  }
  txt <- substituir_bloco(modelo, "carregar_raster", function(nome) codigo_cena(cena, diag, nome))
  txt <- substituir_bloco(txt, "carregar_vetor", function(nome) codigo_vetor(vetor, nome))
  txt <- substituir_bloco(txt, "carregar_serie", function(nome) codigo_serie(serie, cena, diag, nome))

  valores <- list()
  if (!is.null(cena)) {
    bandas <- cena$bandas[!is.na(cena$bandas$grupo), , drop = FALSE]
    bandas <- bandas[order(bandas$ordem), , drop = FALSE]
    for (g in unique(bandas$grupo)) valores[[g]] <- bandas$nome[bandas$grupo == g][1]
    escala <- diag$itens[[cena$itens[1]]]$escala
    conv <- conversao_escala(escala)
    valores$escala <- if (is.na(conv$expr)) conv$comentario else
      paste0("img <- ", sub("x", "img", conv$expr, fixed = TRUE), "  ", conv$comentario)
    valores$conversao <- if (is.na(conv$expr)) "x" else conv$expr
    tem_ndvi <- all(c("red", "nir") %in% names(valores))
    valores$indice_nome <- if (tem_ndvi) "NDVI" else "valor da primeira camada"
    valores$indice_expr <- if (tem_ndvi) {
      sprintf("(x[[\"%s\"]] - x[[\"%s\"]]) / (x[[\"%s\"]] + x[[\"%s\"]])",
              valores$nir, valores$red, valores$nir, valores$red)
    } else {
      "x[[1]]"
    }
    datas <- if (!is.null(serie)) serie$datas else cena$datas
    valores$datas <- sprintf("as.Date(c(%s))", paste(texto_r(format(datas)), collapse = ", "))
  }
  for (g in names(ROTULOS_GRUPO)) {
    if (is.null(valores[[g]])) valores[[g]] <- paste0("NOME_DA_BANDA_", toupper(g))
  }
  for (nm in names(valores)) txt <- gsub(paste0("{", nm, "}"), valores[[nm]], txt, fixed = TRUE)
  txt
}

conversao_escala <- function(escala) {
  com <- "  # converte para reflect\u00e2ncia 0-1"
  switch(escala$tipo,
    inteiro_10000 = if (isTRUE(escala$deslocamento == -0.1)) {
      list(expr = "(x - 1000) / 10000", comentario = "# remove o deslocamento e converte para reflect\u00e2ncia 0-1")
    } else {
      list(expr = "x / 10000", comentario = trimws(com))
    },
    landsat_c2 = list(expr = "x * 0.0000275 - 0.2", comentario = trimws(com)),
    reflectancia_0_1 = list(expr = NA_character_, comentario = "# os valores j\u00e1 est\u00e3o em reflect\u00e2ncia 0-1"),
    list(expr = NA_character_, comentario = "# confira a escala dos valores antes de calcular \u00edndices")
  )
}

# Expressão R que lê um único raster diagnosticado
expressao_raster <- function(item) {
  if (length(item$fontes) == 1) sprintf("terra::rast(%s)", texto_r(item$fontes)) else item$nome
}

codigo_cena <- function(cena, diag, nome) {
  if (is.null(cena)) return(paste0(nome, " <- terra::rast(\"SEU_RASTER.tif\")"))
  itens <- diag$itens[cena$itens]
  if (length(itens) == 1) return(paste(nome, "<-", expressao_raster(itens[[1]])))
  # Bandas em arquivos separados: empilha na grade da banda de maior resolução
  fontes <- vapply(itens, function(i) if (length(i$fontes) == 1) i$fontes else NA_character_, "")
  res <- vapply(itens, function(i) i$resolucao[1], numeric(1))
  if (anyNA(fontes)) {
    objs <- vapply(itens, function(i) i$nome, "")
    return(sprintf("%s <- c(%s)  # junte as bandas na mesma grade se necess\u00e1rio", nome, paste(objs, collapse = ", ")))
  }
  ordem <- c(which.min(res), setdiff(seq_along(fontes), which.min(res)))
  paste0(
    "arquivos <- c(\n  ", paste(texto_r(unname(fontes[ordem])), collapse = ",\n  "), "\n)\n",
    "referencia <- terra::rast(arquivos[1])  # grade de refer\u00eancia (maior resolu\u00e7\u00e3o)\n",
    nome, " <- terra::rast(lapply(arquivos, function(f) terra::resample(terra::rast(f), referencia, method = \"near\")))"
  )
}

codigo_serie <- function(serie, cena, diag, nome) {
  if (is.null(serie)) {
    # Série dentro de um único raster (uma camada por data)
    return(sprintf("%s <- as.list(%s)  # uma camada por data",
                   nome, if (is.null(cena)) "SEU_RASTER" else expressao_raster(diag$itens[[cena$itens[1]]])))
  }
  cenas <- Filter(function(cn) cn$id %in% serie$cenas, diag$cenas)
  cenas <- cenas[order(vapply(cenas, function(cn) as.numeric(cn$datas[1]), numeric(1)))]
  exprs <- vapply(cenas, function(cn) {
    itens <- diag$itens[cn$itens]
    if (length(itens) == 1) return(expressao_raster(itens[[1]]))
    fontes <- vapply(itens, function(i) if (length(i$fontes) == 1) i$fontes else i$nome, "")
    sprintf("terra::rast(c(%s))", paste(texto_r(fontes), collapse = ", "))
  }, "")
  paste0(nome, " <- list(  # em ordem de data\n  ", paste(exprs, collapse = ",\n  "), "\n)")
}

codigo_vetor <- function(vetor, nome) {
  if (is.null(vetor)) return(paste0(nome, " <- sf::st_read(\"SEU_VETOR.gpkg\")"))
  if (vetor$tipo == "vetor") {
    fonte <- if (!is.null(vetor$fonte) && !is.na(vetor$fonte)) {
      sprintf("sf::st_read(%s)", texto_r(vetor$fonte))
    } else {
      vetor$nome
    }
    return(paste(nome, "<-", fonte))
  }
  tabela <- if (!is.null(vetor$fonte) && !is.na(vetor$fonte)) {
    sep <- vetor$sep %||% ","
    switch(sep,
      ";" = sprintf("utils::read.csv2(%s)", texto_r(vetor$fonte)),
      "," = sprintf("utils::read.csv(%s)", texto_r(vetor$fonte)),
      sprintf("utils::read.csv(%s, sep = %s)", texto_r(vetor$fonte), texto_r(sep)))
  } else {
    vetor$nome
  }
  coords <- paste(texto_r(vetor$tabela$colunas_coord), collapse = ", ")
  if (is.na(vetor$crs$epsg)) {
    return(sprintf("%s <- sf::st_as_sf(%s, coords = c(%s))  # informe o CRS: crs = <c\u00f3digo EPSG>",
                   nome, tabela, coords))
  }
  sprintf("%s <- sf::st_as_sf(%s, coords = c(%s), crs = %s)", nome, tabela, coords, vetor$crs$epsg)
}
