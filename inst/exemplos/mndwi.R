# MNDWI = (verde - SWIR1) / (verde + SWIR1)
{carregar_raster:img}
{escala}
mndwi <- (img[["{green}"]] - img[["{swir1}"]]) / (img[["{green}"]] + img[["{swir1}"]])
names(mndwi) <- "MNDWI"
terra::plot(mndwi, main = "MNDWI")
agua <- mndwi > 0  # limiar inicial; ajuste olhando a imagem
terra::plot(agua, main = "Água (MNDWI > 0)")
