# Diagnóstico de vetores e de tabelas com coordenadas -------------------------

GEOMETRIAS <- c(POINT = "pontos", MULTIPOINT = "pontos",
                LINESTRING = "linhas", MULTILINESTRING = "linhas",
                POLYGON = "poligonos", MULTIPOLYGON = "poligonos")

diagnosticar_vetor <- function(v, nome, id, tabela = NULL) {
  tipos <- unique(as.character(sf::st_geometry_type(v)))
  geometrias <- unique(stats::na.omit(GEOMETRIAS[tipos]))
  crs <- descrever_crs(sf::st_crs(v))
  colunas <- setdiff(names(v), attr(v, "sf_column"))

  # Colunas de texto/fator com poucas categorias podem ser rótulos de classe
  rotulos <- colunas[vapply(colunas, function(cl) {
    x <- v[[cl]]
    (is.character(x) || is.factor(x)) &&
      length(unique(stats::na.omit(x))) %in% 2:50 &&
      length(unique(stats::na.omit(x))) < nrow(v)
  }, logical(1))]

  vazias <- sum(sf::st_is_empty(v))
  invalidas <- if ("poligonos" %in% geometrias) sum(!sf::st_is_valid(v), na.rm = TRUE) else 0L

  item <- list(
    id = id, tipo = if (is.null(tabela)) "vetor" else "tabela", nome = nome,
    objeto = v, n_feicoes = nrow(v), geometrias = geometrias,
    tipos_sf = tipos, crs = crs,
    extensao = if (nrow(v) > vazias) as.vector(sf::st_bbox(v))[c(1, 3, 2, 4)] else rep(NA_real_, 4),
    colunas = colunas, colunas_rotulo = rotulos,
    vazias = vazias, invalidas = invalidas,
    tabela = tabela
  )

  a <- list(tabela$alertas)
  if (!crs$definido) {
    a[[length(a) + 1]] <- alerta(id, "O vetor n\u00e3o tem CRS definido. Defina com sf::st_crs(v) <- 4326 (ou o c\u00f3digo EPSG correto).")
  }
  if (vazias > 0) {
    a[[length(a) + 1]] <- alerta(id, sprintf("%d fei\u00e7\u00f5es t\u00eam geometria vazia.", vazias))
  }
  if (invalidas > 0) {
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "%d pol\u00edgonos t\u00eam geometria inv\u00e1lida; corrija com sf::st_make_valid().", invalidas))
  }
  if (!length(geometrias)) {
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "Tipo de geometria n\u00e3o reconhecido (%s).", paste(tipos, collapse = ", ")))
  }
  item$alertas <- juntar_alertas(a)
  item
}

PARES_COORD <- list(
  c("decimallongitude", "decimallatitude"),
  c("longitude", "latitude"),
  c("lon", "lat"), c("long", "lat"), c("lng", "lat"),
  c("x", "y"), c("coordx", "coordy"), c("xcoord", "ycoord"),
  c("easting", "northing"), c("utmx", "utmy"), c("utme", "utmn")
)

detectar_colunas_coord <- function(df) {
  normal <- gsub("[^a-z0-9]", "", tolower(names(df)))
  for (par in PARES_COORD) {
    ix <- match(par, normal)
    if (!anyNA(ix)) return(names(df)[ix])
  }
  NULL
}

como_numero <- function(x) {
  if (is.numeric(x)) return(x)
  suppressWarnings(as.numeric(sub(",", ".", as.character(x), fixed = TRUE)))
}

diagnosticar_tabela <- function(df, nome, id, crs_tabela = NULL) {
  cols <- detectar_colunas_coord(df)
  if (is.null(cols)) {
    return(list(
      id = id, tipo = "tabela", nome = nome, objeto = df, n_feicoes = nrow(df),
      geometrias = character(), crs = descrever_crs(sf::NA_crs_),
      colunas = names(df), sem_coordenadas = TRUE,
      alertas = alerta(id, sprintf(
        "N\u00e3o encontrei colunas de coordenadas na tabela (colunas: %s). Use nomes como lon/lat, longitude/latitude ou x/y.",
        paste(utils::head(names(df), 8), collapse = ", ")))
    ))
  }

  a <- list()
  x <- como_numero(df[[cols[1]]])
  y <- como_numero(df[[cols[2]]])
  df[[cols[1]]] <- x
  df[[cols[2]]] <- y
  ok <- is.finite(x) & is.finite(y)
  if (any(!ok)) {
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "%d linhas sem coordenadas v\u00e1lidas foram ignoradas.", sum(!ok)))
  }
  df <- df[ok, , drop = FALSE]
  x <- x[ok]
  y <- y[ok]

  geo <- all(abs(x) <= 180) && all(abs(y) <= 90)
  if (!is.null(crs_tabela)) {
    crs <- sf::st_crs(crs_tabela)
  } else if (geo) {
    crs <- sf::st_crs(4326)
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "As colunas %s/%s parecem graus decimais; assumi WGS 84 (EPSG:4326). Se for outro sistema, informe crs_tabela.",
      cols[1], cols[2]), "info")
  } else if (all(abs(x) <= 90) && all(abs(y) <= 180)) {
    crs <- sf::NA_crs_
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "Os valores de %s passam de 90: latitude e longitude podem estar trocadas.", cols[2]))
  } else {
    crs <- sf::NA_crs_
    a[[length(a) + 1]] <- alerta(id, sprintf(
      "As coordenadas (%s/%s) parecem projetadas (ex.: UTM). Informe o sistema com crs_tabela, ex.: crs_tabela = 32718 (UTM 18S).",
      cols[1], cols[2]))
  }

  v <- sf::st_as_sf(df, coords = cols, crs = crs, remove = FALSE)
  diagnosticar_vetor(v, nome, id, tabela = list(
    colunas_coord = cols, alertas = juntar_alertas(a)))
}
