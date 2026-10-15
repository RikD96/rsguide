#' Tabela de regras de recomendação
#'
#' Devolve a tabela de regras usada por [sugerir_analises()]. Cada linha é
#' uma análise, com a condição para sugeri-la, a justificativa, os cuidados e
#' os pacotes R recomendados. Use esta função para consultar as regras ou
#' como ponto de partida para criar as suas.
#'
#' @param arquivo Opcional. Caminho de um CSV (UTF-8) com regras próprias.
#'   Se omitido, usa a tabela que acompanha o pacote
#'   (`system.file("regras", "regras.csv", package = "rsguia")`).
#'
#' @details
#' Colunas obrigatórias:
#' * `id`: identificador curto e único (ex.: `"ndvi"`). O modelo de código
#'   da análise é procurado em `inst/exemplos/<id>.R`; regras próprias podem
#'   indicar outro arquivo na coluna opcional `exemplo`.
#' * `analise`, `categoria`: nome da análise e grupo a que pertence.
#' * `condicao`: expressão com etiquetas produzidas por [diagnosticar()],
#'   combinadas com `&` (e), `|` (ou) e `!` (não). Exemplo:
#'   `"banda:green & banda:nir | banda:green & banda:swir1"`.
#' * `justificativa`: por que a análise é possível com esses dados.
#' * `cuidados`: pressupostos e cuidados, separados por `|`.
#' * `pacotes`: pacotes R sugeridos, separados por `;`.
#'
#' Etiquetas disponíveis: `raster`, `vetor`, `tabela`, `multiespectral`,
#' `mde`, `serie_temporal`, `serie_longa`, `sobreposicao`, `crs_diferente`,
#' `banda:<grupo>` (`coastal`, `blue`, `green`, `red`, `rededge`, `nir`,
#' `swir1`, `swir2`, `thermal`, `qualidade`), `escala:<tipo>`
#' (`reflectancia_0_1`, `inteiro_10000`, `landsat_c2`, `inteiro_8bits`,
#' `indice`, `categorica`, `elevacao`, `desconhecida`) e `vetor:<tipo>`
#' (`pontos`, `linhas`, `poligonos`, `rotulado`).
#'
#' @return Um `data.frame` com as regras.
#'
#' @examples
#' regras <- regras_rsguia()
#' regras[, c("id", "analise", "condicao")]
#'
#' # Acrescentando uma regra própria
#' nova <- data.frame(
#'   id = "gndvi", analise = "GNDVI", categoria = "Índices de vegetação",
#'   condicao = "banda:green & banda:nir",
#'   justificativa = "Usa o verde no lugar do vermelho; sensível à clorofila.",
#'   cuidados = "Use reflectância de superfície | Remova nuvens", pacotes = "terra"
#' )
#' minhas_regras <- rbind(regras, nova)
#'
#' @export
regras_rsguia <- function(arquivo = NULL) {
  regras <- if (is.null(arquivo)) {
    ler_tabela_interna("regras.csv")
  } else {
    utils::read.csv(arquivo, stringsAsFactors = FALSE, fileEncoding = "UTF-8",
                    na.strings = c("", "NA"))
  }
  validar_regras(regras)
}

COLUNAS_REGRAS <- c("id", "analise", "categoria", "condicao", "justificativa",
                    "cuidados", "pacotes")

validar_regras <- function(regras) {
  if (is.character(regras)) regras <- regras_rsguia(regras)
  if (!is.data.frame(regras)) {
    cli::cli_abort("As regras devem ser um data.frame ou o caminho de um CSV.")
  }
  faltam <- setdiff(COLUNAS_REGRAS, names(regras))
  if (length(faltam)) {
    cli::cli_abort("Faltam colunas na tabela de regras: {.val {faltam}}.")
  }
  if (anyDuplicated(regras$id)) {
    cli::cli_abort("H\u00e1 ids repetidos nas regras: {.val {unique(regras$id[duplicated(regras$id)])}}.")
  }
  if (anyNA(regras$condicao) || any(!nzchar(trimws(regras$condicao)))) {
    cli::cli_abort("Toda regra precisa de uma condi\u00e7\u00e3o.")
  }
  usadas <- unique(unlist(lapply(regras$condicao, function(cond) {
    unlist(lapply(interpretar_condicao(cond), unlist))
  })))
  estranhas <- usadas[!vapply(usadas, etiqueta_conhecida, logical(1))]
  if (length(estranhas)) {
    cli::cli_warn(c(
      "Etiquetas desconhecidas nas condi\u00e7\u00f5es: {.val {estranhas}}.",
      "i" = "Essas regras nunca ser\u00e3o sugeridas. Veja as etiquetas v\u00e1lidas em {.code ?regras_rsguia}."
    ))
  }
  regras
}

etiqueta_conhecida <- function(x) {
  fixas <- c("raster", "vetor", "tabela", "multiespectral", "mde", "serie_temporal",
             "serie_longa", "sobreposicao", "crs_diferente")
  x %in% c(fixas,
           paste0("banda:", names(ROTULOS_GRUPO)),
           paste0("escala:", names(ESCALAS)),
           paste0("vetor:", c("pontos", "linhas", "poligonos", "rotulado")))
}

# "a & b | !c" -> list(list(sim = c("a", "b"), nao = character()),
#                      list(sim = character(), nao = "c"))
interpretar_condicao <- function(condicao) {
  alternativas <- strsplit(condicao, "|", fixed = TRUE)[[1]]
  lapply(alternativas, function(alt) {
    termos <- trimws(strsplit(alt, "&", fixed = TRUE)[[1]])
    termos <- termos[nzchar(termos)]
    negado <- startsWith(termos, "!")
    nomes <- trimws(sub("^!", "", termos))
    list(sim = nomes[!negado], nao = nomes[negado])
  })
}

avaliar_condicao <- function(condicao, tags) {
  any(vapply(interpretar_condicao(condicao), function(alt) {
    all(alt$sim %in% tags) && !any(alt$nao %in% tags)
  }, logical(1)))
}

#' Sugerir análises a partir de um diagnóstico
#'
#' Compara as características encontradas por [diagnosticar()] com a tabela
#' de regras ([regras_rsguia()]) e lista as análises possíveis, cada uma com
#' justificativa, cuidados, pacotes sugeridos e um exemplo de código já
#' preenchido com os nomes dos seus arquivos e bandas. As análises não são
#' executadas.
#'
#' Normalmente não é preciso chamar esta função: [diagnosticar()] já a
#' executa (argumento `sugerir = TRUE`). Use-a para refazer as sugestões com
#' outras regras.
#'
#' @param diagnostico Objeto da classe `rsguia_diagnostico`.
#' @param regras Opcional. Um `data.frame` de regras ou o caminho de um CSV;
#'   veja [regras_rsguia()].
#'
#' @return O mesmo diagnóstico, com o elemento `sugestoes` (um `data.frame`
#'   com uma linha por análise e por conjunto de dados a que ela se aplica).
#'
#' @examples
#' r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
#'                  extent = terra::ext(500000, 500200, 9150000, 9150200))
#' terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
#' names(r) <- c("B2", "B3", "B4", "B8")
#' d <- diagnosticar(r, sugerir = FALSE)
#' d <- sugerir_analises(d)
#' d$sugestoes[, c("analise", "aplica_a")]
#'
#' @export
sugerir_analises <- function(diagnostico, regras = NULL) {
  if (!inherits(diagnostico, "rsguia_diagnostico")) {
    cli::cli_abort("{.arg diagnostico} deve ser o resultado de {.fun diagnosticar}.")
  }
  regras <- if (is.null(regras)) regras_rsguia() else validar_regras(regras)
  ctx <- diagnostico$contextos

  linhas <- list()
  for (k in seq_len(nrow(regras))) {
    regra <- regras[k, , drop = FALSE]
    ok <- vapply(ctx, function(cx) avaliar_condicao(regra$condicao, cx$tags), logical(1))
    alvos <- ctx[ok]
    # Se a regra vale para um conjunto menor de dados (ex.: só a imagem),
    # não a repete para combinações maiores (imagem + pontos, série...)
    alvos <- Filter(function(cx) {
      !any(vapply(alvos, function(outro) {
        length(outro$itens) < length(cx$itens) && all(outro$itens %in% cx$itens)
      }, logical(1)))
    }, alvos)
    for (cx in alvos) {
      linhas[[length(linhas) + 1]] <- data.frame(
        id = regra$id, analise = regra$analise, categoria = regra$categoria,
        contexto = cx$id, aplica_a = cx$rotulo,
        justificativa = regra$justificativa, cuidados = regra$cuidados,
        pacotes = regra$pacotes,
        codigo = montar_codigo(regra, cx, diagnostico),
        stringsAsFactors = FALSE
      )
    }
  }
  diagnostico$sugestoes <- if (length(linhas)) {
    do.call(rbind, linhas)
  } else {
    data.frame(id = character(), analise = character(), categoria = character(),
               contexto = character(), aplica_a = character(), justificativa = character(),
               cuidados = character(), pacotes = character(), codigo = character(),
               stringsAsFactors = FALSE)
  }
  diagnostico
}

#' Ver o código de exemplo de uma análise sugerida
#'
#' Mostra no console o código de exemplo de uma ou mais análises sugeridas,
#' já com os nomes dos seus arquivos e bandas, pronto para copiar.
#'
#' @param diagnostico Objeto da classe `rsguia_diagnostico`.
#' @param analise Id da análise (ex.: `"ndvi"`, coluna `id` de
#'   `diagnostico$sugestoes`). Se omitido, mostra todas.
#'
#' @return O código, invisivelmente, como vetor de texto.
#'
#' @examples
#' r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
#'                  extent = terra::ext(500000, 500200, 9150000, 9150200))
#' terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
#' names(r) <- c("B2", "B3", "B4", "B8")
#' d <- diagnosticar(r)
#' ver_codigo(d, "ndvi")
#'
#' @export
ver_codigo <- function(diagnostico, analise = NULL) {
  if (!inherits(diagnostico, "rsguia_diagnostico")) {
    cli::cli_abort("{.arg diagnostico} deve ser o resultado de {.fun diagnosticar}.")
  }
  s <- diagnostico$sugestoes
  if (is.null(s) || !nrow(s)) {
    cli::cli_abort("Nenhuma an\u00e1lise sugerida. Rode {.fun sugerir_analises} primeiro.")
  }
  if (!is.null(analise)) {
    desconhecidas <- setdiff(analise, s$id)
    if (length(desconhecidas)) {
      cli::cli_abort(c(
        "An\u00e1lise n\u00e3o sugerida para estes dados: {.val {desconhecidas}}.",
        "i" = "Sugeridas: {.val {unique(s$id)}}."
      ))
    }
    s <- s[s$id %in% analise, , drop = FALSE]
  }
  for (k in seq_len(nrow(s))) {
    cat(cli::rule(left = sprintf("%s \u2014 %s", s$analise[k], s$aplica_a[k])), "\n", sep = "")
    cat(if (is.na(s$codigo[k])) "# (sem exemplo de c\u00f3digo para esta an\u00e1lise)" else s$codigo[k], "\n\n", sep = "")
  }
  invisible(s$codigo)
}
