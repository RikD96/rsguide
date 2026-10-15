# Unsupervised classification with k-means
{load_raster:img}
{scale}
set.seed(1)
clusters <- terra::k_means(img, centers = 5)  # try other numbers of clusters
terra::plot(clusters, main = "Spectral clusters (k-means)")
# Compare each cluster with the image to name the classes
# terra::plotRGB(img, r = "{red}", g = "{green}", b = "{blue}", stretch = "lin")
