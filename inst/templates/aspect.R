# Aspect (0 = north, 90 = east, 180 = south, 270 = west)
{load_raster:dem}
aspect <- terra::terrain(dem, v = "aspect", unit = "degrees")
terra::plot(aspect, main = "Aspect (degrees from north)")
