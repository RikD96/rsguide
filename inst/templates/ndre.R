# NDRE = (NIR - red edge) / (NIR + red edge)
{load_raster:img}
{scale}
ndre <- (img[["{nir}"]] - img[["{rededge}"]]) / (img[["{nir}"]] + img[["{rededge}"]])
names(ndre) <- "NDRE"
terra::plot(ndre, main = "NDRE")
