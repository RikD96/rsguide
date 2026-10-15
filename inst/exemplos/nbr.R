# NBR = (NIR - SWIR2) / (NIR + SWIR2)
{carregar_raster:img}
{escala}
nbr <- (img[["{nir}"]] - img[["{swir2}"]]) / (img[["{nir}"]] + img[["{swir2}"]])
names(nbr) <- "NBR"
terra::plot(nbr, main = "NBR")
# Severidade: calcule o NBR de antes e de depois do fogo e subtraia
# dnbr <- nbr_antes - nbr_depois   # valores altos = queima mais severa
