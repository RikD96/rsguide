# Identificação de bandas e sensor --------------------------------------------
#
# A correspondência entre nomes de camadas e bandas fica em
# inst/regras/bandas.csv; os padrões de nome de arquivo de cada sensor, em
# inst/regras/sensores.csv.

GRUPOS_REFLETIVOS <- c("coastal", "blue", "green", "red", "rededge", "nir",
                       "swir1", "swir2")

ROTULOS_GRUPO <- c(
  coastal = "costeiro/aerossol",
  blue = "azul",
  green = "verde",
  red = "vermelho",
  rededge = "borda do vermelho",
  nir = "infravermelho pr\u00f3ximo",
  swir1 = "infravermelho de ondas curtas 1",
  swir2 = "infravermelho de ondas curtas 2",
  thermal = "termal",
  qualidade = "qualidade/m\u00e1scara",
  outro = "outra"
)

tabela_bandas <- function() {
  tab <- ler_tabela_interna("bandas.csv")
  tab$alias <- normalizar_nome_banda(tab$nome)
  tab$ordem <- seq_len(nrow(tab))
  tab
}

tabela_sensores <- function() ler_tabela_interna("sensores.csv")

# "T18LZQ_20230715T150721_B04_10m" -> "t18lzq_20230715t150721_b04"
normalizar_nome_banda <- function(x) {
  x <- tolower(x)
  x <- sub("\\.(tif|tiff|jp2|img|vrt)$", "", x)
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- sub("_[0-9]{2,3}m$", "", x)
  gsub("^_+|_+$", "", x)
}

# Linhas da tabela de bandas compatíveis com um nome (já normalizado). Vale o
# nome exato ou o final do nome; fica só o apelido mais longo, para que
# "sr_b4" (Landsat) vença "b4" (Sentinel-2).
candidatos_banda <- function(nome, tab) {
  ok <- tab$alias == nome | endsWith(nome, paste0("_", tab$alias))
  cand <- tab[ok, , drop = FALSE]
  if (!nrow(cand)) return(cand)
  cand[nchar(cand$alias) == max(nchar(cand$alias)), , drop = FALSE]
}

identificar_bandas <- function(nomes, sensor = NULL, textos = character()) {
  tab <- tabela_bandas()
  sens <- tabela_sensores()
  cand <- lapply(normalizar_nome_banda(nomes), candidatos_banda, tab = tab)

  especificos <- setdiff(sens$sensor, "generico")
  pontos <- vapply(especificos, function(s) {
    sum(vapply(cand, function(cc) s %in% cc$sensor, logical(1)))
  }, numeric(1))
  pistas <- vapply(especificos, function(s) {
    padrao <- sens$padrao_arquivo[sens$sensor == s]
    !is.na(padrao) && any(grepl(padrao, textos, perl = TRUE))
  }, logical(1))
  # O nome do arquivo só desempata se alguma banda já bateu com o sensor
  total <- pontos + 2 * (pistas & pontos > 0)

  empatados <- character()
  if (!is.null(sensor)) {
    if (!sensor %in% sens$sensor) {
      cli::cli_abort(c(
        "Sensor desconhecido: {.val {sensor}}.",
        "i" = "Op\u00e7\u00f5es: {.val {sens$sensor}}."
      ))
    }
    escolhido <- sensor
    confianca <- "informado pelo usu\u00e1rio"
  } else if (max(total) > 0) {
    empatados <- names(total)[total == max(total)]
    escolhido <- empatados[1]
    confianca <- if (length(empatados) > 1) {
      "baixa"
    } else if (pistas[[escolhido]] || pontos[[escolhido]] >= 3) {
      "alta"
    } else {
      "m\u00e9dia"
    }
  } else if (any(vapply(cand, function(cc) "generico" %in% cc$sensor, logical(1)))) {
    escolhido <- "generico"
    confianca <- NA_character_
  } else {
    escolhido <- NA_character_
    confianca <- NA_character_
  }

  linhas <- lapply(seq_along(nomes), function(i) {
    cc <- cand[[i]]
    sel <- cc[cc$sensor %in% escolhido, , drop = FALSE]
    if (!nrow(sel)) sel <- cc[cc$sensor == "generico", , drop = FALSE]
    if (!nrow(sel)) {
      return(data.frame(camada = i, nome = nomes[i], banda = NA_character_,
                        grupo = NA_character_, comprimento_onda_nm = NA_real_,
                        ordem = NA_integer_, stringsAsFactors = FALSE))
    }
    sel <- sel[1, ]
    data.frame(camada = i, nome = nomes[i], banda = sel$banda, grupo = sel$grupo,
               comprimento_onda_nm = sel$comprimento_onda_nm, ordem = sel$ordem,
               stringsAsFactors = FALSE)
  })

  list(
    sensor = escolhido,
    rotulo = if (is.na(escolhido)) NA_character_ else sens$rotulo[sens$sensor == escolhido],
    confianca = confianca,
    empatados = if (length(empatados) > 1) empatados else character(),
    pontuacao = total,
    bandas = do.call(rbind, linhas)
  )
}
