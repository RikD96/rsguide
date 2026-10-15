# Geradores de dados sintéticos para os testes (nada é baixado da internet).
# Área fictícia em UTM 18S, próxima a Cruzeiro do Sul (AC).

EXT_TESTE <- c(700000, 700300, 9150000, 9150300)

raster_falso <- function(nomes = c("B2", "B3", "B4", "B8", "B11", "B12"),
                         escala = 10000, crs = "EPSG:32718", ext = EXT_TESTE,
                         n = 30, semente = 1) {
  set.seed(semente)
  r <- terra::rast(nrows = n, ncols = n, nlyrs = length(nomes), crs = crs,
                   extent = terra::ext(ext))
  v <- stats::runif(terra::ncell(r) * length(nomes), 0.01, 0.5) * escala
  terra::values(r) <- if (escala > 1) round(v) else v
  names(r) <- nomes
  r
}

mde_falso <- function(nome = "elevacao", ext = EXT_TESTE) {
  set.seed(2)
  r <- terra::rast(nrows = 40, ncols = 40, crs = "EPSG:32718", extent = terra::ext(ext))
  terra::values(r) <- 180 + 60 * sin(seq_len(terra::ncell(r)) / 90) + stats::runif(terra::ncell(r))
  names(r) <- nome
  r
}

# Pontos dentro (ou fora) da extensão de teste, em graus (EPSG:4326)
pontos_falsos <- function(n = 15, dentro = TRUE) {
  set.seed(3)
  caixa <- sf::st_bbox(c(xmin = EXT_TESTE[1], ymin = EXT_TESTE[3],
                         xmax = EXT_TESTE[2], ymax = EXT_TESTE[4]),
                       crs = sf::st_crs(32718))
  caixa <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(caixa), 4326))
  desloc <- if (dentro) 0 else 5
  data.frame(
    especie = sample(c("acai", "buriti", "pupunha"), n, replace = TRUE),
    lon = stats::runif(n, caixa[["xmin"]] + 1e-4, caixa[["xmax"]] - 1e-4) + desloc,
    lat = stats::runif(n, caixa[["ymin"]] + 1e-4, caixa[["ymax"]] - 1e-4)
  )
}

poligonos_falsos <- function() {
  quadrado <- function(x0, y0, l = 100) {
    sf::st_polygon(list(rbind(c(x0, y0), c(x0 + l, y0), c(x0 + l, y0 + l),
                              c(x0, y0 + l), c(x0, y0))))
  }
  sf::st_sf(parcela = c("P1", "P2"),
            geometry = sf::st_sfc(quadrado(700020, 9150020), quadrado(700150, 9150150),
                                  crs = 32718))
}

# Grava rasters numa pasta temporária e devolve o caminho da pasta
pasta_com_rasters <- function(lista) {
  pasta <- tempfile("rsguia_")
  dir.create(pasta)
  for (nm in names(lista)) {
    terra::writeRaster(lista[[nm]], file.path(pasta, paste0(nm, ".tif")))
  }
  pasta
}

# Mapa de classes (ex.: tipo MapBiomas) com 4 classes em manchas
mapa_classes_falso <- function() {
  set.seed(4)
  r <- terra::rast(nrows = 30, ncols = 30, crs = "EPSG:32718", extent = terra::ext(EXT_TESTE))
  terra::values(r) <- rep(sample(c(3L, 12L, 15L, 33L), 36, replace = TRUE), each = 25)
  names(r) <- "cobertura"
  r
}
