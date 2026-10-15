# Normalização das entradas ---------------------------------------------------
#
# Cada entrada (objeto, caminho de arquivo ou pasta) vira um ou mais "itens
# brutos": list(tipo = "raster" | "vetor" | "tabela", objeto, nome).

EXT_RASTER <- c("tif", "tiff", "vrt", "img", "jp2", "nc", "grd", "asc")
EXT_VETOR <- c("shp", "gpkg", "geojson", "json", "kml")
EXT_TABELA <- c("csv", "txt", "tsv")

coletar_entradas <- function(entradas, nomes) {
  itens <- list()
  for (i in seq_along(entradas)) {
    itens <- c(itens, normalizar_entrada(entradas[[i]], nomes[[i]]))
  }
  itens
}

normalizar_entrada <- function(x, nome) {
  if (inherits(x, "SpatRaster")) {
    return(list(list(tipo = "raster", objeto = x, nome = nome)))
  }
  if (inherits(x, "SpatVector")) {
    return(list(list(tipo = "vetor", objeto = sf::st_as_sf(x), nome = nome)))
  }
  if (inherits(x, "sfc")) {
    return(list(list(tipo = "vetor", objeto = sf::st_sf(geometry = x), nome = nome)))
  }
  if (inherits(x, "sf")) {
    return(list(list(tipo = "vetor", objeto = x, nome = nome)))
  }
  if (is.data.frame(x)) {
    return(list(list(tipo = "tabela", objeto = x, nome = nome)))
  }
  if (is.character(x)) {
    return(unlist(lapply(x, ler_caminho), recursive = FALSE))
  }
  if (is.list(x)) {
    nm <- names(x) %||% rep("", length(x))
    nm[nm == ""] <- paste0(nome, "[[", which(nm == ""), "]]")
    return(coletar_entradas(x, nm))
  }
  cli::cli_abort(c(
    "N\u00e3o sei diagnosticar objetos da classe {.cls {class(x)}}.",
    "i" = "Use um SpatRaster, um objeto sf, um data.frame com coordenadas ou o caminho de um arquivo/pasta."
  ))
}

ler_caminho <- function(caminho) {
  if (!file.exists(caminho)) {
    cli::cli_abort("Arquivo ou pasta n\u00e3o encontrado: {.path {caminho}}")
  }
  if (dir.exists(caminho)) {
    arquivos <- list.files(caminho, full.names = TRUE)
    arquivos <- arquivos[extensao_arquivo(arquivos) %in% c(EXT_RASTER, EXT_VETOR, EXT_TABELA)]
    if (!length(arquivos)) {
      cli::cli_abort("A pasta {.path {caminho}} n\u00e3o tem rasters, vetores ou tabelas reconhec\u00edveis.")
    }
    return(unlist(lapply(arquivos, ler_caminho), recursive = FALSE))
  }
  ext <- extensao_arquivo(caminho)
  nome <- sem_extensao(caminho)
  if (ext %in% EXT_RASTER) {
    return(list(list(tipo = "raster", objeto = terra::rast(caminho), nome = nome)))
  }
  if (ext %in% EXT_VETOR) {
    return(list(list(tipo = "vetor", objeto = sf::st_read(caminho, quiet = TRUE), nome = nome)))
  }
  if (ext %in% EXT_TABELA) {
    return(list(list(tipo = "tabela", objeto = ler_csv(caminho), nome = nome)))
  }
  cli::cli_abort("Formato de arquivo n\u00e3o reconhecido: {.path {caminho}}")
}

# Lê CSV com vírgula ou ponto e vírgula como separador
ler_csv <- function(caminho) {
  cabecalho <- readLines(caminho, n = 1, warn = FALSE)
  contagem <- vapply(c(",", ";", "\t"), function(s) lengths(regmatches(cabecalho, gregexpr(s, cabecalho, fixed = TRUE))), numeric(1))
  sep <- names(which.max(contagem))
  utils::read.table(caminho, header = TRUE, sep = sep, dec = if (sep == ";") "," else ".",
                    quote = "\"", stringsAsFactors = FALSE, check.names = FALSE,
                    comment.char = "", fill = TRUE)
}
