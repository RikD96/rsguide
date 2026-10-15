# Datas em nomes de arquivos, nomes de camadas e metadados --------------------

# Extrai a primeira data de cada texto. Reconhece AAAAMMDD, AAAA-MM-DD,
# AAAA_MM_DD e o formato juliano do MODIS (A + ano + dia do ano).
extrair_data <- function(x) {
  saida <- rep(as.Date(NA), length(x))

  padrao <- paste0("(?<![0-9])(19|20)[0-9]{2}[-_.]?(0[1-9]|1[0-2])[-_.]?",
                   "(0[1-9]|[12][0-9]|3[01])(?![0-9])")
  m <- regexpr(padrao, x, perl = TRUE)
  if (any(m > 0)) {
    digitos <- gsub("[^0-9]", "", regmatches(x, m))
    saida[m > 0] <- as.Date(digitos, format = "%Y%m%d")
  }

  falta <- which(is.na(saida))
  m <- regexpr("(?<![0-9A-Za-z])A(19|20)[0-9]{5}(?![0-9])", x[falta], perl = TRUE)
  if (any(m > 0)) {
    txt <- substring(regmatches(x[falta], m), 2)
    ano <- as.integer(substr(txt, 1, 4))
    dia <- as.integer(substr(txt, 5, 7))
    d <- as.Date(sprintf("%d-01-01", ano)) + dia - 1
    d[dia < 1 | dia > 366] <- NA
    saida[falta[m > 0]] <- d
  }
  saida
}

datas_raster <- function(r, fontes) {
  n <- terra::nlyr(r)
  tempo <- tryCatch(terra::time(r), error = function(e) NULL)
  if ((inherits(tempo, "Date") || inherits(tempo, "POSIXt")) && any(!is.na(tempo))) {
    return(list(datas = as.Date(tempo), origem = "metadados (terra::time)"))
  }
  d <- extrair_data(names(r))
  if (any(!is.na(d))) return(list(datas = d, origem = "nomes das camadas"))
  if (length(fontes) == 1) {
    d <- extrair_data(basename(fontes))
    if (!is.na(d)) return(list(datas = rep(d, n), origem = "nome do arquivo"))
  }
  list(datas = rep(as.Date(NA), n), origem = NA_character_)
}
