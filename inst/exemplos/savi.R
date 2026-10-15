# SAVI = (1 + L) * (NIR - vermelho) / (NIR + vermelho + L)
{carregar_raster:img}
{escala}
L <- 0.5  # fator de ajuste ao solo
savi <- (1 + L) * (img[["{nir}"]] - img[["{red}"]]) / (img[["{nir}"]] + img[["{red}"]] + L)
names(savi) <- "SAVI"
terra::plot(savi, main = "SAVI")
