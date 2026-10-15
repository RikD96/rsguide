# Prepara os dados de exemplo do Vale do Juruá (Cruzeiro do Sul, AC) usados
# na vignette. Rode uma vez, a partir da raiz do pacote:
#
#   source("data-raw/jurua.R")
#
# Fonte: Earth Search (AWS, acesso público, sem login)
#   - Sentinel-2 L2A, Coleção 1 (sentinel-2-c1-l2a)
#   - MDE Copernicus GLO-30 (cop-dem-glo-30)
# Gera em inst/extdata/:
#   - jurua_s2_AAAAMMDD.tif  (2 datas, estação seca; 7 bandas a 10 m;
#     números digitais originais: reflectância = (valor - 1000) / 10000)
#   - jurua_mde_copernicus.tif
#   - jurua_parcelas.csv     (pontos FICTÍCIOS, só para demonstração)
#
# Requer: terra, sf, jsonlite e conexão com a internet.

stac <- "https://earth-search.aws.element84.com/v1/search"
centro <- c(lon = -72.70, lat = -7.62)   # rio Juruá, cidade e floresta
meia_largura <- 1250                     # metros -> recorte de 2,5 x 2,5 km
anos <- c(2019, 2024)
meses <- c("07-01", "08-31")             # estação seca: menos nuvens
bandas <- c(B02 = "blue", B03 = "green", B04 = "red", B05 = "rededge1",
            B08 = "nir", B11 = "swir16", B12 = "swir22")
saida <- file.path("inst", "extdata")
dir.create(saida, showWarnings = FALSE, recursive = TRUE)

# Área de interesse em UTM 18S (mesmo CRS do tile T18MYS)
crs_utm <- "EPSG:32718"
cxy <- terra::project(cbind(centro[["lon"]], centro[["lat"]]), from = "EPSG:4326", to = crs_utm)
aoi <- terra::ext(cxy[1] - meia_largura, cxy[1] + meia_largura,
                  cxy[2] - meia_largura, cxy[2] + meia_largura)
aoi_ll <- terra::project(aoi, from = crs_utm, to = "EPSG:4326")
bbox <- paste(round(as.vector(aoi_ll)[c(1, 3, 2, 4)], 5), collapse = ",")

buscar <- function(colecao, datas = NULL) {
  url <- paste0(stac, "?collections=", colecao, "&bbox=", bbox, "&limit=100")
  if (!is.null(datas)) url <- paste0(url, "&datetime=", datas)
  jsonlite::fromJSON(url, simplifyVector = FALSE)$features
}

ler_recorte <- function(href, grade = NULL, metodo = "near") {
  href <- sub("^s3://([^/]+)/", "https://\\1.s3.amazonaws.com/", href)
  r <- terra::rast(paste0("/vsicurl/", href))
  # Mantém os números digitais originais (o GDAL aplicaria escala e deslocamento)
  terra::scoff(r) <- cbind(1, 0)
  if (terra::crs(r, describe = TRUE)$code != "32718") {
    stop("O tile não está em UTM 18S; ajuste a área de interesse.")
  }
  r <- terra::crop(r, aoi, snap = "out")
  if (!is.null(grade)) r <- terra::resample(r, grade, method = metodo)
  r
}

# Proporção de nuvem/sombra no recorte, pela banda SCL
nuvem_no_recorte <- function(f) {
  scl <- terra::values(ler_recorte(f$assets$scl$href))
  mean(scl %in% c(0, 1, 3, 8, 9, 10), na.rm = TRUE)
}

grade <- terra::rast(aoi, resolution = 10, crs = crs_utm)

for (ano in anos) {
  periodo <- sprintf("%d-%sT00:00:00Z/%d-%sT23:59:59Z", ano, meses[1], ano, meses[2])
  itens <- buscar("sentinel-2-c1-l2a", periodo)
  itens <- itens[grepl("T18MYS", vapply(itens, `[[`, "", "id"))]
  if (!length(itens)) stop("Nenhuma imagem encontrada em ", ano)
  cc <- vapply(itens, function(f) f$properties[["eo:cloud_cover"]], numeric(1))
  candidatos <- itens[order(cc)][seq_len(min(5, length(itens)))]
  nuvem <- vapply(candidatos, nuvem_no_recorte, numeric(1))
  f <- candidatos[[which.min(nuvem)]]
  data <- as.Date(substr(f$properties$datetime, 1, 10))
  message(sprintf("%d: %s (nuvem no recorte: %.1f%%)", ano, f$id, 100 * min(nuvem)))

  camadas <- lapply(bandas, function(b) ler_recorte(f$assets[[b]]$href, grade))
  img <- terra::rast(camadas)
  names(img) <- names(bandas)
  arquivo <- file.path(saida, sprintf("jurua_s2_%s.tif", format(data, "%Y%m%d")))
  terra::writeRaster(img, arquivo, datatype = "INT2U", overwrite = TRUE,
                     gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2"))
}

# MDE Copernicus GLO-30, reprojetado para a grade UTM a 30 m
dem <- buscar("cop-dem-glo-30")[[1]]
grade30 <- terra::aggregate(grade, 3)
mde_ll <- terra::rast(paste0("/vsicurl/", sub("^s3://([^/]+)/", "https://\\1.s3.amazonaws.com/",
                                             dem$assets$data$href)))
mde_ll <- terra::crop(mde_ll, terra::ext(aoi_ll) + 0.01)
mde <- terra::project(mde_ll, grade30, method = "bilinear")
names(mde) <- "elevacao"
terra::writeRaster(round(mde, 1), file.path(saida, "jurua_mde_copernicus.tif"),
                   datatype = "FLT4S", overwrite = TRUE,
                   gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3"))

# Parcelas FICTÍCIAS, sorteadas dentro do recorte
set.seed(2024)
pts <- terra::spatSample(aoi, 25, method = "random", lonlat = FALSE)
pts_ll <- terra::project(pts, from = crs_utm, to = "EPSG:4326")
parcelas <- data.frame(
  parcela = sprintf("P%02d", 1:25),
  longitude = round(pts_ll[, 1], 6),
  latitude = round(pts_ll[, 2], 6)
)
utils::write.csv(parcelas, file.path(saida, "jurua_parcelas.csv"), row.names = FALSE)

tamanhos <- file.size(list.files(saida, full.names = TRUE))
message(sprintf("Pronto: %d arquivos, %.2f MB no total.", length(tamanhos), sum(tamanhos) / 2^20))
