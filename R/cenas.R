# Cenas, séries temporais e sobreposição --------------------------------------
#
# Cena: um ou mais rasters que formam uma mesma imagem (ex.: bandas do
# Sentinel-2 em arquivos separados, mesma data e mesma área).
# Série temporal: cenas da mesma área em datas diferentes.

extensao_em <- function(extensao, crs_origem, crs_destino) {
  e <- terra::ext(extensao)
  if (!isFALSE(mesmo_crs(crs_origem, crs_destino))) return(as.vector(e))
  tryCatch(as.vector(terra::project(e, from = crs_origem$wkt, to = crs_destino$wkt)),
           error = function(err) NULL)
}

# Interseção sobre união de duas extensões (xmin, xmax, ymin, ymax)
iou <- function(a, b) {
  larg <- max(0, min(a[2], b[2]) - max(a[1], b[1]))
  alt <- max(0, min(a[4], b[4]) - max(a[3], b[3]))
  inter <- larg * alt
  uniao <- (a[2] - a[1]) * (a[4] - a[3]) + (b[2] - b[1]) * (b[4] - b[3]) - inter
  if (uniao <= 0) return(0)
  inter / uniao
}

mesma_area <- function(a, b, limiar = 0.5) {
  if (a$crs$definido != b$crs$definido) return(FALSE)
  eb <- if (a$crs$definido) extensao_em(b$extensao, b$crs, a$crs) else b$extensao
  !is.null(eb) && iou(a$extensao, eb) >= limiar
}

data_unica <- function(item) {
  if (length(item$datas_unicas) == 1) item$datas_unicas else as.Date(NA)
}

compativel_cena <- function(itens, novo) {
  todos <- c(itens, list(novo))
  if (any(vapply(todos, function(i) length(i$datas_unicas) > 1, logical(1)))) return(FALSE)
  if (!identical(data_unica(itens[[1]]), data_unica(novo))) return(FALSE)
  bandas <- lapply(todos, function(i) stats::na.omit(i$bandas$banda))
  if (any(lengths(bandas) == 0)) return(FALSE)
  if (anyDuplicated(unlist(bandas))) return(FALSE)
  sensores <- unique(stats::na.omit(vapply(todos, function(i) i$sensor$sensor, "")))
  if (length(sensores) > 1) return(FALSE)
  mesma_area(itens[[1]], novo)
}

agrupar_cenas <- function(rasters) {
  grupos <- list()
  for (it in rasters) {
    alvo <- NA
    for (k in seq_along(grupos)) {
      if (compativel_cena(grupos[[k]], it)) {
        alvo <- k
        break
      }
    }
    if (is.na(alvo)) grupos[[length(grupos) + 1]] <- list(it) else grupos[[alvo]] <- c(grupos[[alvo]], list(it))
  }
  lapply(seq_along(grupos), function(k) finalizar_cena(grupos[[k]], paste0("C", k)))
}

finalizar_cena <- function(itens, id) {
  bandas <- do.call(rbind, lapply(itens, function(i) cbind(item = i$id, i$bandas)))
  grupos <- unique(bandas$grupo[!is.na(bandas$grupo)])
  n_espectrais <- sum(bandas$grupo %in% GRUPOS_REFLETIVOS)
  limiar <- opcao("min_bandas_multiespectral", 4)
  datas <- sort(unique(do.call(c, lapply(itens, function(i) i$datas_unicas))))
  escalas <- unique(vapply(itens, function(i) i$escala$tipo, ""))
  sensores <- stats::na.omit(vapply(itens, function(i) i$sensor$sensor, ""))
  a <- list()

  multiespectral <- n_espectrais >= limiar
  if (!multiespectral && length(itens) == 1 && n_espectrais == 0 &&
      itens[[1]]$n_camadas >= limiar &&
      escalas %in% c("reflectancia_0_1", "inteiro_10000", "landsat_c2")) {
    multiespectral <- TRUE
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "O raster tem %d camadas com valores de reflect\u00e2ncia, mas n\u00e3o reconheci as bandas; tratei-o como multiespectral.",
      itens[[1]]$n_camadas), "info")
  }

  tags <- c("raster", sprintf("banda:%s", setdiff(grupos, "outro")),
            sprintf("escala:%s", escalas))
  if (multiespectral) tags <- c(tags, "multiespectral")
  if (length(itens) == 1 && itens[[1]]$mde$mde) tags <- c(tags, "mde")
  if (length(datas) >= 2) {
    tags <- c(tags, "serie_temporal")
    if (length(datas) >= opcao("min_datas_serie_longa", 10)) tags <- c(tags, "serie_longa")
  }

  if (length(itens) > 1) {
    res <- unique(t(vapply(itens, function(i) round(i$resolucao, 6), numeric(2))))
    if (nrow(res) > 1) {
      a[[length(a) + 1]] <- alerta(id, "As bandas desta cena t\u00eam resolu\u00e7\u00f5es diferentes; reamostre para a mesma grade (terra::resample) antes de combin\u00e1-las.", "info")
    }
    if (length(escalas) > 1) {
      a[[length(a) + 1]] <- alerta(id, "Os arquivos desta cena t\u00eam escalas de valores diferentes; padronize antes de combin\u00e1-los.")
    }
  }

  rotulo <- if (length(itens) == 1) {
    sprintf("'%s'", itens[[1]]$nome)
  } else {
    sprintf("cena com %d arquivos%s", length(itens),
            if (length(datas) == 1) paste0(" (", format(datas), ")") else "")
  }

  list(
    id = id, rotulo = rotulo,
    itens = vapply(itens, function(i) i$id, ""),
    datas = datas, bandas = bandas,
    sensor = if (length(sensores)) names(sort(table(sensores), decreasing = TRUE))[1] else NA_character_,
    escala = escalas, multiespectral = multiespectral,
    crs = itens[[1]]$crs, extensao = itens[[1]]$extensao,
    tags = unique(tags),
    alertas = juntar_alertas(a)
  )
}

agrupar_series <- function(cenas) {
  datadas <- Filter(function(cn) length(cn$datas) == 1, cenas)
  sem_data <- Filter(function(cn) length(cn$datas) == 0 && any(cn$bandas$grupo %in% GRUPOS_REFLETIVOS), cenas)
  grupos <- list()
  for (cn in datadas) {
    alvo <- NA
    for (k in seq_along(grupos)) {
      if (mesma_area(grupos[[k]][[1]], cn)) {
        alvo <- k
        break
      }
    }
    if (is.na(alvo)) grupos[[length(grupos) + 1]] <- list(cn) else grupos[[alvo]] <- c(grupos[[alvo]], list(cn))
  }

  series <- list()
  for (g in grupos) {
    datas <- sort(unique(do.call(c, lapply(g, function(cn) cn$datas))))
    if (length(datas) < 2) next
    id <- paste0("S", length(series) + 1)
    bandas_comuns <- Reduce(intersect, lapply(g, function(cn) grep("^banda:", cn$tags, value = TRUE)))
    tags <- c("raster", "serie_temporal", bandas_comuns)
    if (length(datas) >= opcao("min_datas_serie_longa", 10)) tags <- c(tags, "serie_longa")
    if (all(vapply(g, function(cn) cn$multiespectral, logical(1)))) tags <- c(tags, "multiespectral")

    a <- list()
    escalas <- unique(unlist(lapply(g, function(cn) cn$escala)))
    if (length(escalas) > 1) {
      a[[length(a) + 1]] <- alerta(id, "As imagens da s\u00e9rie t\u00eam escalas de valores diferentes; padronize antes de comparar datas.")
    }
    sensores <- unique(stats::na.omit(vapply(g, function(cn) cn$sensor, "")))
    if (length(sensores) > 1) {
      a[[length(a) + 1]] <- alerta(id, sprintf(
        "A s\u00e9rie mistura sensores (%s); harmonize os dados antes de comparar datas.",
        paste(sensores, collapse = ", ")))
    }
    sem_data_aqui <- Filter(function(cn) mesma_area(g[[1]], cn), sem_data)
    if (length(sem_data_aqui)) {
      a[[length(a) + 1]] <- alerta(id, sprintf(
        "Na mesma \u00e1rea h\u00e1 imagens sem data identificada (%s). Inclua a data no nome do arquivo (AAAAMMDD) ou use terra::time().",
        paste(vapply(sem_data_aqui, function(cn) cn$rotulo, ""), collapse = ", ")))
    }

    series[[length(series) + 1]] <- list(
      id = id, cenas = vapply(g, function(cn) cn$id, ""),
      itens = unlist(lapply(g, function(cn) cn$itens)),
      datas = datas, n_datas = length(datas),
      tags = unique(tags), alertas = juntar_alertas(a)
    )
  }
  series
}

# Várias imagens da mesma área sem data: pode ser uma série não reconhecida
alertas_sem_data <- function(cenas) {
  sem_data <- Filter(function(cn) length(cn$datas) == 0 && any(cn$bandas$grupo %in% GRUPOS_REFLETIVOS), cenas)
  if (length(sem_data) < 2) return(NULL)
  for (i in seq_along(sem_data)) {
    for (j in seq_along(sem_data)) {
      if (i < j && mesma_area(sem_data[[i]], sem_data[[j]])) {
        return(alerta("geral", "H\u00e1 v\u00e1rias imagens da mesma \u00e1rea sem data identificada. Se forem datas diferentes, inclua a data no nome do arquivo (AAAAMMDD) ou use terra::time() para que o rsguia reconhe\u00e7a a s\u00e9rie temporal."))
      }
    }
  }
  NULL
}

avaliar_sobreposicao <- function(cena, vetor) {
  base <- data.frame(cena = cena$id, vetor = vetor$id, status = "indeterminado",
                     proporcao = NA_real_, crs_igual = NA, stringsAsFactors = FALSE)
  if (!cena$crs$definido || !vetor$crs$definido || !length(vetor$geometrias)) return(base)

  base$crs_igual <- mesmo_crs(cena$crs, vetor$crs)
  crs_r <- sf::st_crs(cena$crs$wkt)
  e <- unname(cena$extensao)
  caixa <- sf::st_as_sfc(sf::st_bbox(c(xmin = e[1], ymin = e[3], xmax = e[2], ymax = e[4]), crs = crs_r))
  prop <- tryCatch({
    s2 <- suppressMessages(sf::sf_use_s2(FALSE))
    on.exit(suppressMessages(sf::sf_use_s2(s2)), add = TRUE)
    geom <- sf::st_geometry(vetor$objeto)
    geom <- geom[!sf::st_is_empty(geom)]
    if (!base$crs_igual) geom <- sf::st_transform(geom, crs_r)
    mean(lengths(suppressMessages(sf::st_intersects(geom, caixa))) > 0)
  }, error = function(err) NA_real_)

  base$proporcao <- prop
  base$status <- if (is.na(prop)) "indeterminado" else if (prop == 1) "total" else if (prop > 0) "parcial" else "nenhuma"
  base
}

alertas_sobreposicao <- function(s, cenas, vetores) {
  cn <- cenas[[match(s$cena, vapply(cenas, function(x) x$id, ""))]]
  vt <- vetores[[match(s$vetor, vapply(vetores, function(x) x$id, ""))]]
  alvo <- paste(s$vetor, "x", s$cena)
  a <- list()
  if (isFALSE(s$crs_igual)) {
    a[[length(a) + 1]] <- alerta(vt$id, sprintf(
      "CRS diferentes (raster: %s; vetor: %s). O rsguia reprojetou s\u00f3 para verificar a sobreposi\u00e7\u00e3o; antes de analisar, reprojete o vetor: sf::st_transform(v, terra::crs(r)).",
      texto_crs(cn$crs), texto_crs(vt$crs)))
  }
  if (s$status == "nenhuma") {
    a[[length(a) + 1]] <- alerta(alvo, sprintf(
      "Nenhuma fei\u00e7\u00e3o de '%s' cai dentro de %s. Confira o CRS e se os dados s\u00e3o da mesma regi\u00e3o.",
      vt$nome, cn$rotulo))
  } else if (s$status == "parcial") {
    a[[length(a) + 1]] <- alerta(alvo, sprintf(
      "S\u00f3 %s das fei\u00e7\u00f5es de '%s' caem dentro de %s.", fmt_pct(s$proporcao), vt$nome, cn$rotulo), "info")
  } else if (s$status == "indeterminado") {
    a[[length(a) + 1]] <- alerta(alvo, sprintf(
      "N\u00e3o foi poss\u00edvel verificar a sobreposi\u00e7\u00e3o entre '%s' e %s (CRS ausente).", vt$nome, cn$rotulo))
  }
  juntar_alertas(a)
}
