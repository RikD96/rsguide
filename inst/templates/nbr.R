# NBR = (NIR - SWIR2) / (NIR + SWIR2)
{load_raster:img}
{scale}
nbr <- (img[["{nir}"]] - img[["{swir2}"]]) / (img[["{nir}"]] + img[["{swir2}"]])
names(nbr) <- "NBR"
terra::plot(nbr, main = "NBR")
# Burn severity: compute NBR before and after the fire and subtract
# dnbr <- nbr_before - nbr_after   # higher values = more severe burn
