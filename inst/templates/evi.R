# EVI = 2.5 * (NIR - red) / (NIR + 6 * red - 7.5 * blue + 1)
{load_raster:img}
{scale}
nir <- img[["{nir}"]]
red <- img[["{red}"]]
blue <- img[["{blue}"]]
evi <- 2.5 * (nir - red) / (nir + 6 * red - 7.5 * blue + 1)
names(evi) <- "EVI"
terra::plot(evi, main = "EVI")
