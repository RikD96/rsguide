# Métodos de impressão --------------------------------------------------------

#' @export
print.rsguia_diagnostico <- function(x, ...) {
  cat(cli::rule(left = "Diagn\u00f3stico rsguia", line = 2), "\n", sep = "")
  tipos <- table(vapply(x$itens, `[[`, "", "tipo"))
  cat("Entradas: ", paste(sprintf("%d %s", tipos, names(tipos)), collapse = ", "), "\n", sep = "")

  for (it in x$itens) {
    cat("\n", cli::rule(left = sprintf("%s \u00b7 %s (%s)", it$id, it$nome, it$tipo)), "\n", sep = "")
    if (it$tipo == "raster") imprimir_raster(it) else imprimir_vetor(it)
  }

  multi <- Filter(function(cn) length(cn$itens) > 1, x$cenas)
  if (length(multi)) {
    cat("\n", cli::rule(left = "Cenas combinadas"), "\n", sep = "")
    for (cn in multi) {
      linha(sprintf("%s: %s \u2014 arquivos %s", cn$id, cn$rotulo, paste(cn$itens, collapse = ", ")))
    }
  }

  if (length(x$series)) {
    cat("\n", cli::rule(left = "S\u00e9ries temporais"), "\n", sep = "")
    for (s in x$series) {
      linha(sprintf("%s: %d datas, de %s a %s (arquivos %s)", s$id, s$n_datas,
                    format(min(s$datas)), format(max(s$datas)), paste(s$itens, collapse = ", ")))
    }
  }

  if (!is.null(x$sobreposicoes)) {
    cat("\n", cli::rule(left = "Sobreposi\u00e7\u00e3o raster \u00d7 vetor"), "\n", sep = "")
    rotulos <- c(total = "total", parcial = "parcial", nenhuma = "nenhuma",
                 indeterminado = "n\u00e3o verificada")
    for (k in seq_len(nrow(x$sobreposicoes))) {
      s <- x$sobreposicoes[k, ]
      extra <- if (s$status == "parcial") paste0(" (", fmt_pct(s$proporcao), " das fei\u00e7\u00f5es)") else ""
      linha(sprintf("%s \u00d7 %s: %s%s", s$vetor, s$cena, rotulos[[s$status]], extra))
    }
  }

  if (nrow(x$alertas)) {
    cat("\n", cli::rule(left = "Alertas"), "\n", sep = "")
    for (k in seq_len(nrow(x$alertas))) {
      simb <- if (x$alertas$nivel[k] == "aviso") cli::col_yellow("!") else cli::col_blue("i")
      cat(simb, " [", x$alertas$item[k], "] ", x$alertas$mensagem[k], "\n", sep = "")
    }
  }
  invisible(x)
}

linha <- function(...) cat(cli::symbol$bullet, " ", ..., "\n", sep = "")

imprimir_raster <- function(it) {
  res <- it$resolucao_m
  txt_res <- if (abs(res[1] - res[2]) < 1e-6 * max(res)) fmt_num(res[1], if (res[1] < 10) 1 else 0) else
    paste(fmt_num(res, 1), collapse = " \u00d7 ")
  aprox <- if (isTRUE(it$crs$lonlat)) "~" else ""
  unid <- if (it$crs$definido) " m" else " (unidades do CRS)"
  linha(sprintf("Camadas: %d | Dimens\u00f5es: %s linhas \u00d7 %s colunas | Resolu\u00e7\u00e3o: %s%s%s",
                it$n_camadas, fmt_num(it$dimensoes[1]), fmt_num(it$dimensoes[2]), aprox, txt_res, unid))
  linha("CRS: ", texto_crs(it$crs))
  e <- it$extensao
  dig <- if (isTRUE(it$crs$lonlat)) 4 else 0
  linha(sprintf("Extens\u00e3o: x de %s a %s; y de %s a %s",
                fmt_num(e[1], dig), fmt_num(e[2], dig), fmt_num(e[3], dig), fmt_num(e[4], dig)))

  if (it$mde$mde) {
    linha(sprintf("Prov\u00e1vel MDE (confian\u00e7a %s): %s", it$mde$confianca, it$mde$motivo))
  } else if (!is.na(it$sensor$sensor)) {
    conf <- if (is.na(it$sensor$confianca)) "" else paste0(" \u2014 confian\u00e7a ", it$sensor$confianca)
    linha("Sensor prov\u00e1vel: ", it$sensor$rotulo, conf)
  } else {
    linha("Sensor: n\u00e3o identificado")
  }

  b <- it$bandas
  idx <- !is.na(b$grupo)
  if (any(idx)) {
    desc <- sprintf("%s = %s", b$nome[idx], ROTULOS_GRUPO[b$grupo[idx]])
    linha("Bandas: ", paste(desc, collapse = "; "))
  }
  if (any(!idx) && !it$mde$mde) {
    linha("Camadas n\u00e3o reconhecidas: ", paste(utils::head(b$nome[!idx], 6), collapse = ", "),
          if (sum(!idx) > 6) ", ..." else "")
  }
  linha("Escala dos valores: ", it$escala$descricao)
  faixa <- c(min(it$estatisticas$minimo, na.rm = TRUE), max(it$estatisticas$maximo, na.rm = TRUE))
  dig <- if (all(faixa == round(faixa)) && diff(faixa) > 2) 0 else 2
  linha(sprintf("Valores: m\u00ednimo %s, m\u00e1ximo %s", fmt_num(faixa[1], dig), fmt_num(faixa[2], dig)))
  linha("NA (sem dado): ", fmt_pct(max(it$estatisticas$prop_na), 1),
        if (it$n_camadas > 1) " na camada com mais NA" else "")
  if (length(it$datas_unicas)) {
    d <- it$datas_unicas
    txt <- if (length(d) <= 3) paste(format(d), collapse = ", ") else
      sprintf("%d datas, de %s a %s", length(d), format(min(d)), format(max(d)))
    linha("Data(s): ", txt, " (", it$origem_datas, ")")
  }
}

imprimir_vetor <- function(it) {
  if (isTRUE(it$sem_coordenadas)) {
    linha(sprintf("Tabela com %d linhas, sem coordenadas reconhecidas", it$n_feicoes))
    return(invisible())
  }
  geo <- c(pontos = "pontos", linhas = "linhas", poligonos = "pol\u00edgonos")
  linha(sprintf("Geometria: %s | Fei\u00e7\u00f5es: %s",
                paste(geo[it$geometrias], collapse = ", "), fmt_num(it$n_feicoes)))
  if (!is.null(it$tabela)) {
    linha("Coordenadas das colunas: ", paste(it$tabela$colunas_coord, collapse = " / "))
  }
  linha("CRS: ", texto_crs(it$crs))
  if (length(it$colunas)) {
    linha("Colunas: ", paste(utils::head(it$colunas, 8), collapse = ", "),
          if (length(it$colunas) > 8) ", ..." else "")
  }
  if (length(it$colunas_rotulo)) {
    linha("Poss\u00edveis colunas de classe: ", paste(it$colunas_rotulo, collapse = ", "))
  }
}
