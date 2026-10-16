# Show the example code of a suggested analysis

Prints the example code of one or more suggested analyses, already
filled in with your file and band names, ready to copy.

## Usage

``` r
show_code(diagnosis, analysis = NULL)
```

## Arguments

- diagnosis:

  An object of class `rsguide_diagnosis`.

- analysis:

  Id of the analysis (e.g. `"ndvi"`, column `id` of
  `diagnosis$suggestions`). If omitted, shows all of them.

## Value

The code, invisibly, as a character vector.

## Examples

``` r
r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
                 extent = terra::ext(500000, 500200, 9150000, 9150200))
terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
names(r) <- c("B2", "B3", "B4", "B8")
d <- diagnose(r)
show_code(d, "ndvi")
#> ── NDVI (Normalized Difference Vegetation Index) - 'r' ─────────────────────────
#> # NDVI = (NIR - red) / (NIR + red)
#> img <- r
#> img <- img / 10000  # converts to 0-1 reflectance
#> ndvi <- (img[["B8"]] - img[["B4"]]) / (img[["B8"]] + img[["B4"]])
#> names(ndvi) <- "NDVI"
#> terra::plot(ndvi, main = "NDVI")
#> # terra::writeRaster(ndvi, "ndvi.tif")
#> 
```
