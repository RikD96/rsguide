# Prepares the Jurua River example data (Cruzeiro do Sul, Acre, Brazil) used
# in the vignettes. Run once, from the package root:
#
#   source("data-raw/jurua.R")
#
# Source: Earth Search (AWS, public access, no login)
#   - Sentinel-2 L2A, Collection 1 (sentinel-2-c1-l2a)
#   - Copernicus GLO-30 DEM (cop-dem-glo-30)
# Writes to inst/extdata/:
#   - jurua_s2_YYYYMMDD.tif  (2 dates, dry season; 7 bands at 10 m;
#     original digital numbers: reflectance = (value - 1000) / 10000)
#   - jurua_dem_copernicus.tif
#   - jurua_plots.csv        (FICTITIOUS points, for demonstration only)
#
# Requires: terra, jsonlite and an internet connection.

stac <- "https://earth-search.aws.element84.com/v1/search"
center <- c(lon = -72.654, lat = -7.649)  # Jurua River meander, floodplain and forest
half_width <- 1250                       # meters -> 2.5 x 2.5 km crop
years <- c(2019, 2024)
months <- c("07-01", "08-31")            # dry season: fewer clouds
bands <- c(B02 = "blue", B03 = "green", B04 = "red", B05 = "rededge1",
           B08 = "nir", B11 = "swir16", B12 = "swir22")
out_dir <- file.path("inst", "extdata")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Area of interest in UTM 18S (same CRS as tile T18MYS)
crs_utm <- "EPSG:32718"
cxy <- terra::project(cbind(center[["lon"]], center[["lat"]]), from = "EPSG:4326", to = crs_utm)
aoi <- terra::ext(cxy[1] - half_width, cxy[1] + half_width,
                  cxy[2] - half_width, cxy[2] + half_width)
aoi_ll <- terra::project(aoi, from = crs_utm, to = "EPSG:4326")
bbox <- paste(round(as.vector(aoi_ll)[c(1, 3, 2, 4)], 5), collapse = ",")

search <- function(collection, dates = NULL) {
  url <- paste0(stac, "?collections=", collection, "&bbox=", bbox, "&limit=100")
  if (!is.null(dates)) url <- paste0(url, "&datetime=", dates)
  jsonlite::fromJSON(url, simplifyVector = FALSE)$features
}

https_url <- function(href) sub("^s3://([^/]+)/", "https://\\1.s3.amazonaws.com/", href)

read_crop <- function(href, grid = NULL, method = "near") {
  r <- terra::rast(paste0("/vsicurl/", https_url(href)))
  # Keep the original digital numbers (GDAL would apply scale and offset)
  terra::scoff(r) <- cbind(1, 0)
  if (terra::crs(r, describe = TRUE)$code != "32718") {
    stop("The tile is not in UTM 18S; adjust the area of interest.")
  }
  r <- terra::crop(r, aoi, snap = "out")
  if (!is.null(grid)) r <- terra::resample(r, grid, method = method)
  r
}

# Proportion of cloud/shadow in the crop, from the SCL band
cloud_in_crop <- function(f) {
  scl <- terra::values(read_crop(f$assets$scl$href))
  mean(scl %in% c(0, 1, 3, 8, 9, 10), na.rm = TRUE)
}

grid <- terra::rast(aoi, resolution = 10, crs = crs_utm)

for (year in years) {
  period <- sprintf("%d-%sT00:00:00Z/%d-%sT23:59:59Z", year, months[1], year, months[2])
  items <- search("sentinel-2-c1-l2a", period)
  items <- items[grepl("T18MYS", vapply(items, `[[`, "", "id"))]
  if (!length(items)) stop("No image found in ", year)
  cc <- vapply(items, function(f) f$properties[["eo:cloud_cover"]], numeric(1))
  candidates <- items[order(cc)][seq_len(min(5, length(items)))]
  cloud <- vapply(candidates, cloud_in_crop, numeric(1))
  f <- candidates[[which.min(cloud)]]
  date <- as.Date(substr(f$properties$datetime, 1, 10))
  message(sprintf("%d: %s (cloud in crop: %.1f%%)", year, f$id, 100 * min(cloud)))

  layers <- lapply(bands, function(b) read_crop(f$assets[[b]]$href, grid))
  img <- terra::rast(layers)
  names(img) <- names(bands)
  file <- file.path(out_dir, sprintf("jurua_s2_%s.tif", format(date, "%Y%m%d")))
  terra::writeRaster(img, file, datatype = "INT2U", overwrite = TRUE,
                     gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2"))
}

# Copernicus GLO-30 DEM, reprojected to the UTM grid at 30 m
dem <- search("cop-dem-glo-30")[[1]]
grid30 <- terra::aggregate(grid, 3)
dem_ll <- terra::rast(paste0("/vsicurl/", https_url(dem$assets$data$href)))
dem_ll <- terra::crop(dem_ll, terra::ext(aoi_ll) + 0.01)
dem_utm <- terra::project(dem_ll, grid30, method = "bilinear")
names(dem_utm) <- "elevation"
terra::writeRaster(round(dem_utm, 1), file.path(out_dir, "jurua_dem_copernicus.tif"),
                   datatype = "FLT4S", overwrite = TRUE,
                   gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3"))

# FICTITIOUS plots, randomly placed inside the crop
set.seed(2024)
pts <- terra::spatSample(aoi, 25, method = "random", lonlat = FALSE)
pts_ll <- terra::project(pts, from = crs_utm, to = "EPSG:4326")
plots <- data.frame(
  plot = sprintf("P%02d", 1:25),
  longitude = round(pts_ll[, 1], 6),
  latitude = round(pts_ll[, 2], 6)
)
utils::write.csv(plots, file.path(out_dir, "jurua_plots.csv"), row.names = FALSE)

sizes <- file.size(list.files(out_dir, full.names = TRUE))
message(sprintf("Done: %d files, %.2f MB in total.", length(sizes), sum(sizes) / 2^20))
