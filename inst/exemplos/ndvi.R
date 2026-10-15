# NDVI = (NIR - vermelho) / (NIR + vermelho)
{carregar_raster:img}
{escala}
ndvi <- (img[["{nir}"]] - img[["{red}"]]) / (img[["{nir}"]] + img[["{red}"]])
names(ndvi) <- "NDVI"
terra::plot(ndvi, main = "NDVI")
# terra::writeRaster(ndvi, "ndvi.tif")
