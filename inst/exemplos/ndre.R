# NDRE = (NIR - borda do vermelho) / (NIR + borda do vermelho)
{carregar_raster:img}
{escala}
ndre <- (img[["{nir}"]] - img[["{rededge}"]]) / (img[["{nir}"]] + img[["{rededge}"]])
names(ndre) <- "NDRE"
terra::plot(ndre, main = "NDRE")
