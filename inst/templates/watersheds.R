# Flow direction, flow accumulation and drainage network
{load_raster:dem}
# Fill spurious depressions first (e.g. whitebox::wbt_fill_depressions())
flow_dir <- terra::terrain(dem, v = "flowdir")
flow_acc <- terra::flowAccumulation(flow_dir)
streams <- flow_acc > 100  # cells draining more than 100 other cells; adjust
terra::plot(streams, main = "Drainage network")
# Watershed of an outlet point, in the DEM's CRS coordinates:
# basin <- terra::watershed(flow_dir, pourpoint = cbind(x, y))
