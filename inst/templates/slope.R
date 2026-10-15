# Slope from the DEM
{load_raster:dem}
slope <- terra::terrain(dem, v = "slope", unit = "degrees")
terra::plot(slope, main = "Slope (degrees)")
