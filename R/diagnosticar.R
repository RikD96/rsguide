#' Diagnosticar dados de sensoriamento remoto
#'
#' Identifica automaticamente o tipo de dado entregue (raster, vetor ou tabela
#' com coordenadas) e descreve suas características: número de camadas,
#' resolução, sistema de coordenadas (CRS), extensão, valores ausentes, bandas
#' e provável sensor, escala dos valores, se o raster parece um modelo digital
#' de elevação (MDE), se há uma série temporal e se os vetores se sobrepõem ao
#' raster.
#'
#' @param ... Um ou mais dados: objetos `SpatRaster` (terra), objetos `sf`,
#'   `data.frame`s com colunas de coordenadas (ex.: `lon`/`lat`, `x`/`y`,
#'   `decimalLongitude`/`decimalLatitude`), caminhos de arquivos (`.tif`,
#'   `.shp`, `.gpkg`, `.csv`...) ou de pastas. Listas também são aceitas.
#' @param sensor Opcional. Força o sensor quando a identificação automática
#'   falha ou é ambígua: `"sentinel2"`, `"landsat89"`, `"landsat457"` ou
#'   `"generico"`.
#' @param crs_tabela Opcional. CRS das coordenadas de tabelas (código EPSG ou
#'   texto aceito por [sf::st_crs()]). Se omitido, graus decimais são
#'   tratados como WGS 84 (EPSG:4326).
#' @param sugerir Se `TRUE` (padrão), já sugere as análises possíveis com
#'   [sugerir_analises()].
#' @param regras Opcional. Regras próprias (`data.frame` ou caminho de CSV)
#'   repassadas a [sugerir_analises()]; veja [regras_rsguia()].
#'
#' @details
#' Rasters grandes não são lidos por inteiro: as estatísticas são estimadas a
#' partir de uma amostra regular de células.
#'
#' Alguns limiares podem ser ajustados com [options()]:
#' * `rsguia.min_bandas_multiespectral` (padrão 4): número mínimo de bandas
#'   espectrais para considerar o dado multiespectral;
#' * `rsguia.min_datas_serie_longa` (padrão 10): número mínimo de datas para
#'   uma série temporal permitir análise de tendência;
#' * `rsguia.tamanho_amostra` (padrão 100000): número de células amostradas.
#'
#' @return Um objeto da classe `rsguia_diagnostico`, uma lista com os
#'   elementos `itens` (diagnóstico de cada dado), `cenas`, `series`,
#'   `sobreposicoes`, `contextos` (conjuntos de etiquetas usados pelas regras
#'   de recomendação), `alertas` e, se `sugerir = TRUE`, `sugestoes`.
#'
#' @examples
#' r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
#'                  extent = terra::ext(500000, 500200, 9150000, 9150200))
#' terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
#' names(r) <- c("B2", "B3", "B4", "B8")
#' diagnosticar(r)
#'
#' @export
diagnosticar <- function(..., sensor = NULL, crs_tabela = NULL, sugerir = TRUE,
                         regras = NULL) {
  entradas <- list(...)
  if (!length(entradas)) {
    cli::cli_abort("Informe ao menos um dado para diagnosticar.")
  }
  nomes <- nomes_das_entradas(entradas, as.list(substitute(list(...)))[-1])
  brutos <- coletar_entradas(entradas, nomes)

  itens <- list()
  cont <- c(raster = 0, vetor = 0, tabela = 0)
  prefixo <- c(raster = "R", vetor = "V", tabela = "T")
  for (b in brutos) {
    cont[b$tipo] <- cont[b$tipo] + 1
    id <- paste0(prefixo[[b$tipo]], cont[[b$tipo]])
    itens[[id]] <- switch(b$tipo,
      raster = diagnosticar_raster(b$objeto, b$nome, id, sensor = sensor),
      vetor = diagnosticar_vetor(b$objeto, b$nome, id),
      tabela = diagnosticar_tabela(b$objeto, b$nome, id, crs_tabela = crs_tabela)
    )
    if (b$tipo != "raster") {
      itens[[id]]$fonte <- b$fonte %||% NA_character_
      itens[[id]]$sep <- b$sep
    }
  }

  rasters <- Filter(function(i) i$tipo == "raster", itens)
  vetores <- Filter(function(i) i$tipo != "raster" && length(i$geometrias) > 0, itens)
  cenas <- if (length(rasters)) agrupar_cenas(rasters) else list()
  series <- agrupar_series(cenas)

  sobreposicoes <- list()
  for (cn in cenas) for (vt in vetores) {
    sobreposicoes[[length(sobreposicoes) + 1]] <- avaliar_sobreposicao(cn, vt)
  }
  alertas_sob <- lapply(sobreposicoes, alertas_sobreposicao, cenas = cenas, vetores = vetores)
  sobreposicoes <- if (length(sobreposicoes)) do.call(rbind, sobreposicoes) else NULL

  alertas <- juntar_alertas(c(
    lapply(itens, `[[`, "alertas"),
    lapply(cenas, `[[`, "alertas"),
    lapply(series, `[[`, "alertas"),
    list(alertas_sem_data(cenas)),
    alertas_sob
  ))
  alertas <- alertas[!duplicated(alertas[c("item", "mensagem")]), , drop = FALSE]
  rownames(alertas) <- NULL

  diag <- structure(
    list(
      itens = itens,
      cenas = cenas,
      series = series,
      sobreposicoes = sobreposicoes,
      contextos = construir_contextos(cenas, series, vetores, sobreposicoes),
      alertas = alertas,
      parametros = list(sensor = sensor, crs_tabela = crs_tabela),
      criado_em = Sys.time()
    ),
    class = "rsguia_diagnostico"
  )
  if (sugerir) diag <- sugerir_analises(diag, regras)
  diag
}

nomes_das_entradas <- function(entradas, expressoes) {
  nm <- names(entradas) %||% rep("", length(entradas))
  vazios <- nm == ""
  nm[vazios] <- vapply(expressoes[vazios], function(e) {
    paste(deparse(e, width.cutoff = 60L), collapse = "")
  }, "")
  nm
}

# Contextos: conjuntos de etiquetas sobre os quais as regras serão avaliadas.
# Um por cena, um por série, um por vetor e um por par cena x vetor.
construir_contextos <- function(cenas, series, vetores, sobreposicoes) {
  ctx <- list()
  novo <- function(id, rotulo, itens, tags) {
    list(id = id, rotulo = rotulo, itens = itens, tags = unique(tags))
  }
  for (cn in cenas) ctx[[cn$id]] <- novo(cn$id, cn$rotulo, cn$itens, cn$tags)
  for (s in series) {
    ctx[[s$id]] <- novo(s$id, sprintf("s\u00e9rie temporal com %d datas", s$n_datas), s$itens, s$tags)
  }
  for (vt in vetores) {
    tags <- c("vetor", sprintf("vetor:%s", vt$geometrias))
    if (vt$tipo == "tabela") tags <- c(tags, "tabela")
    if (length(vt$colunas_rotulo)) tags <- c(tags, "vetor:rotulado")
    ctx[[vt$id]] <- novo(vt$id, sprintf("'%s'", vt$nome), vt$id, tags)
  }
  if (!is.null(sobreposicoes)) {
    for (k in seq_len(nrow(sobreposicoes))) {
      s <- sobreposicoes[k, ]
      tags <- c(ctx[[s$cena]]$tags, ctx[[s$vetor]]$tags)
      if (s$status %in% c("total", "parcial")) tags <- c(tags, "sobreposicao")
      if (isFALSE(s$crs_igual)) tags <- c(tags, "crs_diferente")
      id <- paste(s$cena, s$vetor, sep = "+")
      ctx[[id]] <- novo(id, paste(ctx[[s$cena]]$rotulo, "+", ctx[[s$vetor]]$rotulo),
                        c(ctx[[s$cena]]$itens, s$vetor), tags)
    }
  }
  ctx
}
