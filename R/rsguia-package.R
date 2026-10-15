#' rsguia: diagnosis of remote sensing data and suggestion of analyses
#'
#' rsguia takes remote sensing data, automatically identifies what they are
#' and suggests which analyses are possible. Each suggestion comes with a
#' plain-language rationale, the necessary caveats and an example code
#' snippet already filled in with your files and bands. The package does
#' **not run** the analyses: it diagnoses and recommends.
#'
#' @section Workflow:
#' 1. [diagnose()] takes the data (files, folders or R objects) and describes
#'    each one: type, layers, resolution, coordinate reference system, bands
#'    and sensor, value scale, DEM, time series and raster/vector overlap.
#'    It then calls [suggest_analyses()].
#' 2. `print()` shows the diagnosis, the alerts and the list of suggested
#'    analyses.
#' 3. [summary()][summary.rsguia_diagnosis()] shows the rationale, caveats
#'    and packages of each analysis.
#' 4. [show_code()] prints the example code, ready to copy.
#' 5. [as.data.frame()][as.data.frame.rsguia_diagnosis()] exports the report
#'    as a table.
#'
#' @section Accepted inputs:
#' * Rasters: `.tif`, `.tiff`, `.vrt`, `.img`, `.jp2`, `.nc`, `.grd`, `.asc`
#'   files or `SpatRaster` objects (terra).
#' * Vectors: `.shp`, `.gpkg`, `.geojson`, `.json`, `.kml` files or `sf`,
#'   `sfc` and `SpatVector` objects.
#' * Tables with coordinates: `.csv`, `.txt`, `.tsv` files (separated by
#'   commas, semicolons or tabs) or `data.frame`s. Recognized columns:
#'   `lon`/`lat`, `long`/`lat`, `lng`/`lat`, `longitude`/`latitude`,
#'   `decimalLongitude`/`decimalLatitude` (GBIF), `x`/`y`,
#'   `easting`/`northing`, `utm_x`/`utm_y`, among others.
#' * Folders: every recognized file inside the folder.
#' * Several inputs at once: `diagnose(image, points)`.
#'
#' @section Recognized sensors and bands:
#' * Sentinel-2: `B1`/`B01` to `B12`, `B8A`, `SCL`, also inside file names
#'   such as `..._B04_10m.jp2`.
#' * Landsat 8/9 (Collection 2): `SR_B1` to `SR_B7`, `ST_B10`, `QA_PIXEL` and
#'   the short names `B1` to `B11`.
#' * Landsat 4-7 (Collection 2): `SR_B1` to `SR_B5`, `SR_B7`, `ST_B6`.
#' * Generic names: `blue`, `green`, `red`, `rededge`, `nir`, `swir1`,
#'   `swir2`, `thermal`, the names used in STAC catalogs (`nir08`, `swir16`,
#'   `swir22`, ...) and their Portuguese equivalents (`azul`, `verde`,
#'   `vermelho`, ...).
#'
#' The aliases are listed in `system.file("rules", "bands.csv", package =
#' "rsguia")`. When the names match more than one sensor, the package warns
#' you; set the sensor with `diagnose(x, sensor = "landsat89")`.
#'
#' @section Options:
#' * `rsguia.min_multispectral_bands` (default 4): minimum number of
#'   spectral bands for the data to be considered multispectral.
#' * `rsguia.min_dates_long_series` (default 10): minimum number of dates to
#'   suggest trend analysis.
#' * `rsguia.sample_size` (default 100000): number of cells read to estimate
#'   statistics of large rasters.
#'
#' @section Learn more:
#' * `vignette("case-study-jurua", package = "rsguia")`: case study with
#'   Sentinel-2 images of the Jurua River (Acre, Brazil).
#' * `vignette("custom-rules", package = "rsguia")`: how to add new analyses
#'   to the rules table.
#' * [rsguia_rules()]: the rules table and the available tags.
#' * [jurua_data]: the example data.
#'
#' @keywords package
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end

## mockable bindings: start
## mockable bindings: end
NULL
