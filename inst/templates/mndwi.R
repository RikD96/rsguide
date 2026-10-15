# MNDWI = (green - SWIR1) / (green + SWIR1)
{load_raster:img}
{scale}
mndwi <- (img[["{green}"]] - img[["{swir1}"]]) / (img[["{green}"]] + img[["{swir1}"]])
names(mndwi) <- "MNDWI"
terra::plot(mndwi, main = "MNDWI")
water <- mndwi > 0  # starting threshold; adjust it by looking at the image
terra::plot(water, main = "Water (MNDWI > 0)")
