# Supervised classification with Random Forest
{load_raster:img}
{scale}
# Training samples: points or polygons with a "class" column
# (e.g. forest, pasture, water, urban), collected in the field or on the image
samples <- sf::st_read("training_samples.gpkg")
samples <- sf::st_transform(samples, terra::crs(img))
training <- terra::extract(img, terra::vect(samples))
training$class <- factor(samples$class[training$ID])
training$ID <- NULL
model <- randomForest::randomForest(class ~ ., data = stats::na.omit(training))
print(model)  # out-of-bag error and confusion matrix
land_cover <- terra::predict(img, model, na.rm = TRUE)
terra::plot(land_cover, main = "Land use and land cover")
