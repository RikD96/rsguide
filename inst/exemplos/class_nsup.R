# Classificação não supervisionada com k-means
{carregar_raster:img}
{escala}
set.seed(1)
grupos <- terra::k_means(img, centers = 5)  # teste outros números de grupos
terra::plot(grupos, main = "Grupos espectrais (k-means)")
# Compare cada grupo com a imagem para dar nome às classes
# terra::plotRGB(img, r = "{red}", g = "{green}", b = "{blue}", stretch = "lin")
