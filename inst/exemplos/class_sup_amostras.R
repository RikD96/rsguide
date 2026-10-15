# Classificação supervisionada usando as suas amostras como treino
{carregar_raster:img}
{escala}
{carregar_vetor:amostras}
amostras <- sf::st_transform(amostras, terra::crs(img))
treino <- terra::extract(img, terra::vect(amostras))
treino$classe <- factor(amostras[["{coluna_classe}"]][treino$ID])
treino$ID <- NULL
treino <- stats::na.omit(treino)

# Separa 30% das amostras para validar o mapa
set.seed(1)
validacao <- sample(nrow(treino), round(0.3 * nrow(treino)))
modelo <- randomForest::randomForest(classe ~ ., data = treino[-validacao, ])
previsto <- stats::predict(modelo, treino[validacao, ])
confusao <- table(previsto = previsto, observado = treino$classe[validacao])
print(confusao)  # matriz de confusão
cat("Acurácia global:", round(sum(diag(confusao)) / sum(confusao), 2), "\n")

mapa <- terra::predict(img, modelo, na.rm = TRUE)
terra::plot(mapa, main = "Classificação ({coluna_classe})")
