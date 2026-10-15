# NDWI = (verde - NIR) / (verde + NIR)
{carregar_raster:img}
{escala}
ndwi <- (img[["{green}"]] - img[["{nir}"]]) / (img[["{green}"]] + img[["{nir}"]])
names(ndwi) <- "NDWI"
terra::plot(ndwi, main = "NDWI")
agua <- ndwi > 0  # limiar inicial; ajuste olhando a imagem
terra::plot(agua, main = "Água (NDWI > 0)")
