# Synthetic data generators for the tests (nothing is downloaded).
# Fictitious area in UTM 18S, near Cruzeiro do Sul (Acre, Brazil).

TEST_EXT <- c(700000, 700300, 9150000, 9150300)

fake_raster <- function(names = c("B2", "B3", "B4", "B8", "B11", "B12"),
                        scale = 10000, crs = "EPSG:32718", ext = TEST_EXT,
                        n = 30, seed = 1) {
  set.seed(seed)
  r <- terra::rast(nrows = n, ncols = n, nlyrs = length(names), crs = crs,
                   extent = terra::ext(ext))
  v <- stats::runif(terra::ncell(r) * length(names), 0.01, 0.5) * scale
  terra::values(r) <- if (scale > 1) round(v) else v
  names(r) <- names
  r
}

fake_dem <- function(name = "elevation", ext = TEST_EXT) {
  set.seed(2)
  r <- terra::rast(nrows = 40, ncols = 40, crs = "EPSG:32718", extent = terra::ext(ext))
  terra::values(r) <- 180 + 60 * sin(seq_len(terra::ncell(r)) / 90) + stats::runif(terra::ncell(r))
  names(r) <- name
  r
}

# Points inside (or outside) the test extent, in degrees (EPSG:4326)
fake_points <- function(n = 15, inside = TRUE) {
  set.seed(3)
  box <- sf::st_bbox(c(xmin = TEST_EXT[1], ymin = TEST_EXT[3],
                       xmax = TEST_EXT[2], ymax = TEST_EXT[4]),
                     crs = sf::st_crs(32718))
  box <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(box), 4326))
  shift <- if (inside) 0 else 5
  data.frame(
    species = sample(c("acai", "buriti", "pupunha"), n, replace = TRUE),
    lon = stats::runif(n, box[["xmin"]] + 1e-4, box[["xmax"]] - 1e-4) + shift,
    lat = stats::runif(n, box[["ymin"]] + 1e-4, box[["ymax"]] - 1e-4)
  )
}

fake_polygons <- function() {
  square <- function(x0, y0, l = 100) {
    sf::st_polygon(list(rbind(c(x0, y0), c(x0 + l, y0), c(x0 + l, y0 + l),
                              c(x0, y0 + l), c(x0, y0))))
  }
  sf::st_sf(plot = c("P1", "P2"),
            geometry = sf::st_sfc(square(700020, 9150020), square(700150, 9150150),
                                  crs = 32718))
}

# Class map (MapBiomas-like) with 4 classes in patches
fake_class_map <- function() {
  set.seed(4)
  r <- terra::rast(nrows = 30, ncols = 30, crs = "EPSG:32718", extent = terra::ext(TEST_EXT))
  terra::values(r) <- rep(sample(c(3L, 12L, 15L, 33L), 36, replace = TRUE), each = 25)
  names(r) <- "land_cover"
  r
}

# Writes rasters to a temporary folder and returns the folder path
folder_with_rasters <- function(rasters) {
  folder <- tempfile("rsguia_")
  dir.create(folder)
  for (nm in names(rasters)) {
    terra::writeRaster(rasters[[nm]], file.path(folder, paste0(nm, ".tif")))
  }
  folder
}
