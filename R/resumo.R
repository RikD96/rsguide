# summary() e as.data.frame() -------------------------------------------------

#' Resumo e exportação do diagnóstico
#'
#' `summary()` mostra um resumo dos dados e a lista completa de análises
#' sugeridas, com justificativas, cuidados e pacotes (e, se `codigo = TRUE`,
#' o código de exemplo de cada uma). `as.data.frame()` transforma o relatório
#' numa tabela, que pode ser salva com [utils::write.csv()].
#'
#' @param object,x Objeto da classe `rsguia_diagnostico`, criado por
#'   [diagnosticar()].
#' @param codigo Se `TRUE`, inclui o código de exemplo de cada análise.
#' @param tipo Qual tabela exportar: `"sugestoes"` (uma linha por análise e
#'   conjunto de dados), `"itens"` (uma linha por dado diagnosticado) ou
#'   `"alertas"`.
#' @param row.names,optional Ignorados; existem por compatibilidade com
#'   [base::as.data.frame()].
#' @param ... Ignorado.
#'
#' @return `summary()` devolve um objeto da classe
#'   `summary.rsguia_diagnostico`; `as.data.frame()`, um `data.frame`.
#'
#' @examples
#' r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
#'                  extent = terra::ext(500000, 500200, 9150000, 9150200))
#' terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
#' names(r) <- c("B2", "B3", "B4", "B8")
#' d <- diagnosticar(r)
#' summary(d)
#' tabela <- as.data.frame(d)
#' tabela[, c("analise", "pacotes")]
#' as.data.frame(d, tipo = "itens")
#' \dontrun{
#' utils::write.csv(tabela, "relatorio_rsguia.csv", row.names = FALSE)
#' }
#'
#' @name resumo
NULL

#' @rdname resumo
#' @export
summary.rsguia_diagnostico <- function(object, codigo = FALSE, ...) {
  structure(
    list(itens = as.data.frame(object, tipo = "itens"),
         alertas = object$alertas,
         series = object$series,
         sugestoes = object$sugestoes,
         codigo = codigo),
    class = "summary.rsguia_diagnostico"
  )
}

#' @export
print.summary.rsguia_diagnostico <- function(x, ...) {
  cat(cli::rule(left = "Resumo do diagn\u00f3stico rsguia", line = 2), "\n", sep = "")
  for (k in seq_len(nrow(x$itens))) {
    it <- x$itens[k, ]
    cat(sprintf("%-4s", it$id), it$nome, cli::col_grey(paste0("(", it$tipo, ")")), "\n")
    escrever(it$descricao, 5)
  }
  for (s in x$series) {
    cat("S\u00e9rie temporal:", sprintf("%d datas, de %s a %s", s$n_datas,
                                       format(min(s$datas)), format(max(s$datas))), "\n")
  }
  n_aviso <- sum(x$alertas$nivel == "aviso")
  n_info <- sum(x$alertas$nivel != "aviso")
  if (n_aviso + n_info) {
    cat(sprintf("Alertas: %d aviso(s) e %d informa\u00e7\u00e3o(\u00f5es); veja print() ou as.data.frame(..., tipo = \"alertas\").\n",
                n_aviso, n_info))
  }
  if (!is.null(x$sugestoes)) imprimir_sugestoes(x$sugestoes, codigo = x$codigo)
  invisible(x)
}

#' @rdname resumo
#' @export
as.data.frame.rsguia_diagnostico <- function(x, row.names = NULL, optional = FALSE, ...,
                                             tipo = c("sugestoes", "itens", "alertas")) {
  tipo <- match.arg(tipo)
  switch(tipo,
    alertas = x$alertas,
    itens = tabela_itens(x),
    sugestoes = {
      s <- x$sugestoes
      if (is.null(s)) {
        cli::cli_abort("Este diagn\u00f3stico n\u00e3o tem sugest\u00f5es. Rode {.fun sugerir_analises} primeiro.")
      }
      s$arquivos <- vapply(s$contexto, function(id) {
        itens <- x$itens[x$contextos[[id]]$itens]
        fontes <- unlist(lapply(itens, function(i) {
          f <- if (i$tipo == "raster") i$fontes else i$fonte
          f <- f[!is.na(f)]
          if (length(f)) basename(f) else i$nome
        }))
        paste(unique(fontes), collapse = "; ")
      }, "", USE.NAMES = FALSE)
      colunas <- c("id", "analise", "categoria", "aplica_a", "arquivos", "justificativa",
                   "cuidados", "pacotes", "codigo")
      s <- s[, colunas]
      rownames(s) <- NULL
      s
    }
  )
}

tabela_itens <- function(x) {
  linhas <- lapply(x$itens, function(it) {
    raster <- it$tipo == "raster"
    fonte <- if (raster) paste(it$fontes, collapse = "; ") else (it$fonte %||% NA_character_)
    bandas <- if (raster) {
      b <- it$bandas[!is.na(it$bandas$grupo), , drop = FALSE]
      paste(sprintf("%s=%s", b$nome, b$grupo), collapse = "; ")
    } else NA_character_
    data.frame(
      id = it$id, nome = it$nome, tipo = it$tipo,
      fonte = if (is.null(fonte) || !nzchar(fonte)) NA_character_ else fonte,
      camadas = if (raster) it$n_camadas else NA_integer_,
      feicoes = if (raster) NA_integer_ else it$n_feicoes,
      geometria = if (raster) NA_character_ else paste(it$geometrias, collapse = ", "),
      resolucao_m = if (raster) round(it$resolucao_m[1], 2) else NA_real_,
      crs = texto_crs(it$crs),
      epsg = it$crs$epsg,
      sensor = if (raster) it$sensor$rotulo else NA_character_,
      confianca_sensor = if (raster) it$sensor$confianca else NA_character_,
      bandas = if (is.na(bandas) || !nzchar(bandas)) NA_character_ else bandas,
      escala = if (raster) it$escala$tipo else NA_character_,
      mde = if (raster) it$mde$mde else NA,
      datas = if (raster && length(it$datas_unicas)) paste(format(it$datas_unicas), collapse = "; ") else NA_character_,
      na_max = if (raster) round(max(it$estatisticas$prop_na), 4) else NA_real_,
      descricao = descrever_item(it),
      stringsAsFactors = FALSE
    )
  })
  tab <- do.call(rbind, linhas)
  rownames(tab) <- NULL
  tab
}

# Uma linha de texto que resume um item
descrever_item <- function(it) {
  epsg <- if (is.na(it$crs$epsg)) texto_crs(it$crs) else paste0("EPSG:", it$crs$epsg)
  if (it$tipo == "raster") {
    partes <- c(
      sprintf("%d camada%s", it$n_camadas, if (it$n_camadas > 1) "s" else ""),
      paste0(if (isTRUE(it$crs$lonlat)) "~" else "", fmt_num(it$resolucao_m[1]), " m"),
      epsg,
      if (it$mde$mde) "prov\u00e1vel MDE" else if (!is.na(it$sensor$sensor)) it$sensor$rotulo,
      it$escala$descricao,
      if (length(it$datas_unicas)) paste(format(it$datas_unicas), collapse = ", ")
    )
  } else if (isTRUE(it$sem_coordenadas)) {
    partes <- sprintf("%d linhas, sem coordenadas", it$n_feicoes)
  } else {
    geo <- c(pontos = "pontos", linhas = "linhas", poligonos = "pol\u00edgonos")
    partes <- c(sprintf("%s %s", fmt_num(it$n_feicoes), paste(geo[it$geometrias], collapse = "/")),
                epsg,
                if (length(it$colunas_rotulo)) paste("classes em:", paste(it$colunas_rotulo, collapse = ", ")))
  }
  paste(partes, collapse = " \u00b7 ")
}
