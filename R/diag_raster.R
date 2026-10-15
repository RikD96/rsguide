# Diagnóstico de um raster ----------------------------------------------------

# Lê no máximo `n` células (amostra regular) para estimar estatísticas sem
# carregar rasters grandes inteiros na memória.
amostrar_valores <- function(r, n = opcao("tamanho_amostra", 1e5)) {
  if (terra::ncell(r) <= n) {
    v <- terra::values(r, mat = TRUE)
  } else {
    v <- as.matrix(terra::spatSample(r, size = n, method = "regular",
                                     na.rm = FALSE, as.df = TRUE))
  }
  colnames(v) <- names(r)
  v
}

diagnosticar_raster <- function(r, nome, id, sensor = NULL) {
  fontes <- terra::sources(r)
  fontes <- unique(fontes[nzchar(fontes)])
  nomes <- names(r)
  valores <- amostrar_valores(r)
  crs <- descrever_crs(crs_de_raster(r))
  ext <- unname(as.vector(terra::ext(r)))

  res <- terra::res(r)
  res_m <- if (isTRUE(crs$lonlat)) {
    res * 111320 * c(cos(mean(ext[3:4]) * pi / 180), 1)
  } else {
    res
  }

  ident <- identificar_bandas(nomes, sensor = sensor, textos = c(basename(fontes), nome))
  mde <- detectar_mde(nome, fontes, ident$bandas, valores)
  escala <- if (mde$mde) nova_escala("elevacao") else detectar_escala(valores, ident$bandas, ident$sensor)
  datas <- datas_raster(r, fontes)

  estat <- data.frame(
    camada = nomes,
    minimo = apply(valores, 2, function(x) if (all(is.na(x))) NA else min(x, na.rm = TRUE)),
    maximo = apply(valores, 2, function(x) if (all(is.na(x))) NA else max(x, na.rm = TRUE)),
    media = apply(valores, 2, mean, na.rm = TRUE),
    prop_na = colMeans(is.na(valores)),
    row.names = NULL, stringsAsFactors = FALSE
  )

  item <- list(
    id = id, tipo = "raster", nome = nome, fontes = fontes, objeto = r,
    n_camadas = terra::nlyr(r), nomes = nomes,
    dimensoes = c(linhas = terra::nrow(r), colunas = terra::ncol(r)),
    resolucao = res, resolucao_m = res_m,
    crs = crs, extensao = ext,
    estatisticas = estat,
    sensor = ident[c("sensor", "rotulo", "confianca", "empatados")],
    bandas = ident$bandas,
    escala = escala,
    mde = mde,
    datas = datas$datas,
    datas_unicas = sort(unique(datas$datas[!is.na(datas$datas)])),
    origem_datas = datas$origem
  )
  item$alertas <- alertas_raster(item, valores)
  item
}

alertas_raster <- function(item, valores) {
  id <- item$id
  a <- list()
  if (!item$crs$definido) {
    a[[length(a) + 1]] <- alerta(id, "O raster n\u00e3o tem sistema de coordenadas (CRS) definido. Defina com terra::crs(r) <- \"EPSG:...\" antes de combinar com outros dados.")
  }
  na_alto <- item$estatisticas$camada[item$estatisticas$prop_na > 0.5]
  if (length(na_alto)) {
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "Mais da metade dos pixels \u00e9 NA (sem dado) em: %s. Verifique nuvens, m\u00e1scaras ou o recorte.",
      paste(na_alto, collapse = ", ")))
  }
  completos <- valores[stats::complete.cases(valores), , drop = FALSE]
  if (nrow(completos) && !item$escala$tipo %in% c("categorica", "elevacao")) {
    zeros <- mean(rowSums(completos != 0) == 0)
    if (zeros > 0.05) {
      a[[length(a) + 1]] <- alerta(id, sprintf(
        "%s dos pixels t\u00eam valor 0 em todas as camadas; pode ser \"sem dado\" n\u00e3o declarado. Se for o caso, use terra::NAflag(r) <- 0.",
        fmt_pct(zeros)))
    }
  }
  if (all(is.na(item$bandas$grupo)) && !item$mde$mde && item$n_camadas > 1) {
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "N\u00e3o reconheci os nomes das camadas (%s). Renomeie-as para que o rsguia identifique as bandas, ex.: names(r) <- c(\"blue\", \"green\", \"red\", \"nir\").",
      paste(utils::head(item$nomes, 4), collapse = ", ")))
  }
  if (length(item$sensor$empatados)) {
    rot <- tabela_sensores()
    rot <- rot$rotulo[match(item$sensor$empatados, rot$sensor)]
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "Os nomes das bandas s\u00e3o compat\u00edveis com mais de um sensor (%s). Assumi %s; se estiver errado, use diagnosticar(..., sensor = \"%s\").",
      paste(rot, collapse = ", "), rot[1], item$sensor$empatados[2]))
  }
  tipo <- item$escala$tipo
  if (tipo == "inteiro_10000") {
    msg <- "Os valores parecem reflect\u00e2ncia \u00d7 10.000. Para \u00edndices como EVI e SAVI, converta antes: r / 10000."
    if (isTRUE(item$escala$deslocamento == -0.1)) {
      msg <- "Os menores valores ficam acima de 1000: a imagem parece ter o deslocamento de +1000 do Sentinel-2 L2A (processamento a partir de 25/01/2022, incluindo a Cole\u00e7\u00e3o 1 reprocessada). Converta para reflect\u00e2ncia com (r - 1000) / 10000 antes de calcular \u00edndices."
    } else if (isTRUE(item$sensor$sensor == "sentinel2")) {
      msg <- paste(msg, "Aten\u00e7\u00e3o: imagens Sentinel-2 L2A processadas a partir de 25/01/2022 t\u00eam um deslocamento de \u22121000 [reflect\u00e2ncia = (valor \u2212 1000) / 10000]; alguns provedores j\u00e1 removem esse deslocamento, verifique o seu.")
    }
    a[[length(a) + 1]] <- alerta(id, msg, "info")
  }
  if (tipo == "landsat_c2") {
    a[[length(a) + 1]] <- alerta(id, "Valores da Cole\u00e7\u00e3o 2 do Landsat: converta para reflect\u00e2ncia com r * 0.0000275 - 0.2 antes de calcular \u00edndices.", "info")
  }
  if (tipo == "inteiro_8bits") {
    a[[length(a) + 1]] <- alerta(id, "Valores de 0 a 255 sugerem uma imagem de 8 bits (ex.: composi\u00e7\u00e3o colorida para visualiza\u00e7\u00e3o). \u00cdndices calculados nela n\u00e3o s\u00e3o compar\u00e1veis aos calculados com reflect\u00e2ncia.")
  }
  if (isTRUE(item$mde$confianca == "m\u00e9dia")) {
    a[[length(a) + 1]] <- alerta(id, paste0(
      "Considerei este raster um prov\u00e1vel modelo digital de eleva\u00e7\u00e3o (", item$mde$motivo,
      "). Confirme; se n\u00e3o for, ignore as sugest\u00f5es de relevo."), "info")
  }
  juntar_alertas(a)
}
