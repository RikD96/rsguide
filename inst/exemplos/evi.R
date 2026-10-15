# EVI = 2,5 * (NIR - vermelho) / (NIR + 6 * vermelho - 7,5 * azul + 1)
{carregar_raster:img}
{escala}
nir <- img[["{nir}"]]
vermelho <- img[["{red}"]]
azul <- img[["{blue}"]]
evi <- 2.5 * (nir - vermelho) / (nir + 6 * vermelho - 7.5 * azul + 1)
names(evi) <- "EVI"
terra::plot(evi, main = "EVI")
