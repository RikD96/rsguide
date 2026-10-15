# Supervised classification using your own samples for training
{load_raster:img}
{scale}
{load_vector:samples}
samples <- sf::st_transform(samples, terra::crs(img))
training <- terra::extract(img, terra::vect(samples))
training$class <- factor(samples[["{class_column}"]][training$ID])
training$ID <- NULL
training <- stats::na.omit(training)

# Keep 30% of the samples to validate the map
set.seed(1)
validation <- sample(nrow(training), round(0.3 * nrow(training)))
model <- randomForest::randomForest(class ~ ., data = training[-validation, ])
predicted <- stats::predict(model, training[validation, ])
confusion <- table(predicted = predicted, observed = training$class[validation])
print(confusion)  # confusion matrix
cat("Overall accuracy:", round(sum(diag(confusion)) / sum(confusion), 2), "\n")

land_cover <- terra::predict(img, model, na.rm = TRUE)
terra::plot(land_cover, main = "Classification ({class_column})")
