# Extração dos valores do raster em cada ponto
{carregar_raster:img}
{carregar_vetor:pontos}
pontos <- sf::st_transform(pontos, terra::crs(img))
valores <- terra::extract(img, terra::vect(pontos), ID = FALSE)
resultado <- cbind(pontos, valores)
head(resultado)
