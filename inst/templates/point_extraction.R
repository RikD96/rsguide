# Extract raster values at each point
{load_raster:img}
{load_vector:points}
points <- sf::st_transform(points, terra::crs(img))
values <- terra::extract(img, terra::vect(points), ID = FALSE)
result <- cbind(points, values)
head(result)
