# NDWI = (green - NIR) / (green + NIR)
{load_raster:img}
{scale}
ndwi <- (img[["{green}"]] - img[["{nir}"]]) / (img[["{green}"]] + img[["{nir}"]])
names(ndwi) <- "NDWI"
terra::plot(ndwi, main = "NDWI")
water <- ndwi > 0  # starting threshold; adjust it by looking at the image
terra::plot(water, main = "Water (NDWI > 0)")
