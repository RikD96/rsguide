# Estatística zonal: média do raster dentro de cada polígono
{carregar_raster:img}
{carregar_vetor:poligonos}
poligonos <- sf::st_transform(poligonos, terra::crs(img))
medias <- terra::extract(img, terra::vect(poligonos), fun = mean, na.rm = TRUE, ID = FALSE)
resultado <- cbind(poligonos, medias)
head(resultado)
