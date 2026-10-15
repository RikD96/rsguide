# SAVI = (1 + L) * (NIR - red) / (NIR + red + L)
{load_raster:img}
{scale}
L <- 0.5  # soil adjustment factor
savi <- (1 + L) * (img[["{nir}"]] - img[["{red}"]]) / (img[["{nir}"]] + img[["{red}"]] + L)
names(savi) <- "SAVI"
terra::plot(savi, main = "SAVI")
