# NDVI = (NIR - red) / (NIR + red)
{load_raster:img}
{scale}
ndvi <- (img[["{nir}"]] - img[["{red}"]]) / (img[["{nir}"]] + img[["{red}"]])
names(ndvi) <- "NDVI"
terra::plot(ndvi, main = "NDVI")
# terra::writeRaster(ndvi, "ndvi.tif")
