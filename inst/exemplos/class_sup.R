# Classificação supervisionada com Random Forest
{carregar_raster:img}
{escala}
# Amostras de treino: pontos ou polígonos com uma coluna "classe"
# (ex.: floresta, pasto, água, área urbana), coletados em campo ou na imagem
amostras <- sf::st_read("amostras_treino.gpkg")
amostras <- sf::st_transform(amostras, terra::crs(img))
treino <- terra::extract(img, terra::vect(amostras))
treino$classe <- factor(amostras$classe[treino$ID])
treino$ID <- NULL
modelo <- randomForest::randomForest(classe ~ ., data = stats::na.omit(treino))
print(modelo)  # erro "out-of-bag" e matriz de confusão
mapa <- terra::predict(img, modelo, na.rm = TRUE)
terra::plot(mapa, main = "Uso e cobertura do solo")
