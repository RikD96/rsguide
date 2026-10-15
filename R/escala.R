# Escala dos valores e detecção de MDE ----------------------------------------

ESCALAS <- list(
  reflectancia_0_1 = list(descricao = "reflect\u00e2ncia em escala 0\u20131",
                          fator = 1, deslocamento = 0),
  inteiro_10000 = list(descricao = "inteiros escalonados (reflect\u00e2ncia \u00d7 10.000)",
                       fator = 1e-4, deslocamento = 0),
  landsat_c2 = list(descricao = "inteiros da Cole\u00e7\u00e3o 2 do Landsat, n\u00edvel 2 (reflect\u00e2ncia = valor \u00d7 0,0000275 \u2212 0,2)",
                    fator = 2.75e-5, deslocamento = -0.2),
  inteiro_8bits = list(descricao = "inteiros de 0 a 255 (imagem de 8 bits, provavelmente para visualiza\u00e7\u00e3o)",
                       fator = NA, deslocamento = NA),
  indice = list(descricao = "valores entre \u22121 e 1 (prov\u00e1vel \u00edndice j\u00e1 calculado, como NDVI)",
                fator = NA, deslocamento = NA),
  categorica = list(descricao = "inteiros com poucas categorias (prov\u00e1vel mapa de classes ou m\u00e1scara)",
                    fator = NA, deslocamento = NA),
  elevacao = list(descricao = "valores cont\u00ednuos de eleva\u00e7\u00e3o (provavelmente em metros)",
                  fator = NA, deslocamento = NA),
  desconhecida = list(descricao = "n\u00e3o reconhecida", fator = NA, deslocamento = NA)
)

nova_escala <- function(tipo) c(list(tipo = tipo), ESCALAS[[tipo]])

detectar_escala <- function(valores, bandas, sensor) {
  espectral <- bandas$grupo %in% GRUPOS_REFLETIVOS
  colunas <- if (any(espectral)) which(espectral) else seq_len(ncol(valores))
  v <- as.vector(valores[, colunas])
  v <- v[is.finite(v)]
  if (!length(v)) return(nova_escala("desconhecida"))

  mn <- min(v)
  mx <- max(v)
  inteiro <- all(v == round(v))

  if (!any(espectral) && ncol(valores) == 1 && inteiro && length(unique(v)) <= 30) {
    return(nova_escala("categorica"))
  }
  if (mx <= 1.6 && mn >= -1.05) {
    if (!any(espectral) && mn < -0.2) return(nova_escala("indice"))
    return(nova_escala("reflectancia_0_1"))
  }
  if (inteiro) {
    if (mn >= 0 && mx <= 255) return(nova_escala("inteiro_8bits"))
    validos <- v[v != 0]
    q <- stats::quantile(validos, c(0.01, 0.5, 0.99), names = FALSE)
    landsat <- isTRUE(sensor %in% c("landsat89", "landsat457"))
    sentinel <- isTRUE(sensor == "sentinel2")
    if (mx <= 65535 && ((landsat && q[2] >= 5000) || (!sentinel && q[1] >= 5000))) {
      return(nova_escala("landsat_c2"))
    }
    if (q[3] <= 20000) return(nova_escala("inteiro_10000"))
  }
  nova_escala("desconhecida")
}

PADRAO_MDE <- paste0(
  "(^|[^a-z])(dem|dtm|dsm|mde|mdt|srtm|nasadem|elev[a-z]*|altitude|alos|",
  "aster|glo_?30|copdem|topo[a-z]*)([^a-z]|$)"
)

detectar_mde <- function(nome, fontes, bandas, valores) {
  nao <- list(mde = FALSE, confianca = NA_character_, motivo = NA_character_)
  if (nrow(bandas) != 1 || !is.na(bandas$grupo[1])) return(nao)

  v <- valores[, 1]
  v <- v[is.finite(v)]
  if (length(v) < 2) return(nao)
  mn <- min(v)
  mx <- max(v)
  plausivel <- mn >= -500 && mx <= 9000 && (mx - mn) > 1 &&
    !(mx <= 1.6 && mn >= -1.05)

  textos <- tolower(c(nome, bandas$nome, basename(fontes)))
  nome_sugere <- any(grepl(PADRAO_MDE, textos, perl = TRUE))

  if (nome_sugere && plausivel) {
    return(list(mde = TRUE, confianca = "alta",
                motivo = "o nome sugere eleva\u00e7\u00e3o e os valores s\u00e3o compat\u00edveis"))
  }
  continuo <- length(unique(v)) > 50
  oito_bits <- all(v == round(v)) && mn >= 0 && mx <= 255
  if (plausivel && continuo && !oito_bits) {
    return(list(mde = TRUE, confianca = "m\u00e9dia",
                motivo = sprintf("banda \u00fanica com valores cont\u00ednuos entre %s e %s, t\u00edpicos de eleva\u00e7\u00e3o",
                                 fmt_num(mn), fmt_num(mx))))
  }
  nao
}
