# Funções auxiliares internas -------------------------------------------------

`%||%` <- function(a, b) if (is.null(a)) b else a

# Lê uma opção do pacote (ex.: options(rsguia.min_datas_serie_longa = 12))
opcao <- function(nome, padrao) getOption(paste0("rsguia.", nome), padrao)

# Lê uma tabela de inst/regras/
ler_tabela_interna <- function(arquivo) {
  caminho <- system.file("regras", arquivo, package = "rsguia", mustWork = TRUE)
  utils::read.csv(caminho, stringsAsFactors = FALSE, fileEncoding = "UTF-8",
                  na.strings = c("", "NA"))
}

extensao_arquivo <- function(caminho) {
  b <- basename(caminho)
  ifelse(grepl("\\.[^.]+$", b), tolower(sub(".*\\.", "", b)), "")
}

sem_extensao <- function(caminho) sub("\\.[^.]+$", "", basename(caminho))

# Alertas são guardados como data.frame (item, nivel, mensagem)
alerta <- function(item, mensagem, nivel = "aviso") {
  data.frame(item = item, nivel = nivel, mensagem = mensagem,
             stringsAsFactors = FALSE)
}

juntar_alertas <- function(lista) {
  lista <- Filter(function(x) !is.null(x) && nrow(x) > 0, lista)
  if (!length(lista)) {
    return(data.frame(item = character(), nivel = character(),
                      mensagem = character(), stringsAsFactors = FALSE))
  }
  do.call(rbind, lista)
}

# Sistema de coordenadas ------------------------------------------------------

crs_de_raster <- function(r) {
  wkt <- terra::crs(r)
  if (!nzchar(wkt)) sf::NA_crs_ else sf::st_crs(wkt)
}

descrever_crs <- function(crs) {
  if (is.na(crs)) {
    return(list(definido = FALSE, nome = NA_character_, epsg = NA_integer_,
                lonlat = NA, wkt = NA_character_))
  }
  list(definido = TRUE,
       nome = crs$Name %||% NA_character_,
       epsg = crs$epsg %||% NA_integer_,
       lonlat = isTRUE(sf::st_is_longlat(crs)),
       wkt = crs$wkt)
}

mesmo_crs <- function(a, b) {
  if (!a$definido || !b$definido) return(NA)
  sf::st_crs(a$wkt) == sf::st_crs(b$wkt)
}

texto_crs <- function(crs) {
  if (!crs$definido) return("n\u00e3o definido")
  if (is.na(crs$epsg)) crs$nome else sprintf("%s (EPSG:%s)", crs$nome, crs$epsg)
}

# Formatação de números no padrão brasileiro
fmt_num <- function(x, digitos = 0) {
  formatC(x, format = "f", digits = digitos, big.mark = ".", decimal.mark = ",")
}

fmt_pct <- function(x, digitos = 0) paste0(fmt_num(100 * x, digitos), "%")
