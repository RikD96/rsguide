# NDMI = (NIR - SWIR1) / (NIR + SWIR1)
{carregar_raster:img}
{escala}
ndmi <- (img[["{nir}"]] - img[["{swir1}"]]) / (img[["{nir}"]] + img[["{swir1}"]])
names(ndmi) <- "NDMI"
terra::plot(ndmi, main = "NDMI (umidade da vegetação)")
