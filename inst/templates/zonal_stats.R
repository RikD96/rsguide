# Zonal statistics: mean raster value inside each polygon
{load_raster:img}
{load_vector:polygons}
polygons <- sf::st_transform(polygons, terra::crs(img))
means <- terra::extract(img, terra::vect(polygons), fun = mean, na.rm = TRUE, ID = FALSE)
result <- cbind(polygons, means)
head(result)
