# NDMI = (NIR - SWIR1) / (NIR + SWIR1)
{load_raster:img}
{scale}
ndmi <- (img[["{nir}"]] - img[["{swir1}"]]) / (img[["{nir}"]] + img[["{swir1}"]])
names(ndmi) <- "NDMI"
terra::plot(ndmi, main = "NDMI (vegetation moisture)")
