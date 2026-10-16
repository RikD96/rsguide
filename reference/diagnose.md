# Diagnose remote sensing data

Automatically identifies the type of data provided (raster, vector or
table with coordinates) and describes it: number of layers, resolution,
coordinate reference system (CRS), extent, missing values, bands and
likely sensor, value scale, whether the raster looks like a digital
elevation model (DEM), whether there is a time series and whether the
vectors overlap the rasters. By default it then suggests the possible
analyses with
[`suggest_analyses()`](https://rikd96.github.io/rsguide/reference/suggest_analyses.md).

## Usage

``` r
diagnose(..., sensor = NULL, table_crs = NULL, suggest = TRUE, rules = NULL)
```

## Arguments

- ...:

  One or more datasets: `SpatRaster` objects (terra), `sf` objects,
  `data.frame`s with coordinate columns (e.g. `lon`/`lat`, `x`/`y`,
  `decimalLongitude`/`decimalLatitude`), paths to files (`.tif`, `.shp`,
  `.gpkg`, `.csv`, ...) or folders. Lists are also accepted.

- sensor:

  Optional. Forces the sensor when automatic identification fails or is
  ambiguous: `"sentinel2"`, `"landsat89"`, `"landsat457"` or
  `"generic"`.

- table_crs:

  Optional. CRS of the coordinates in tables (EPSG code or any string
  accepted by
  [`sf::st_crs()`](https://r-spatial.github.io/sf/reference/st_crs.html)).
  If omitted, decimal degrees are assumed to be WGS 84 (EPSG:4326).

- suggest:

  If `TRUE` (default), also suggests the possible analyses with
  [`suggest_analyses()`](https://rikd96.github.io/rsguide/reference/suggest_analyses.md).

- rules:

  Optional. Custom rules (`data.frame` or path to a CSV file) passed to
  [`suggest_analyses()`](https://rikd96.github.io/rsguide/reference/suggest_analyses.md);
  see
  [`rsguide_rules()`](https://rikd96.github.io/rsguide/reference/rsguide_rules.md).

## Value

An object of class `rsguide_diagnosis`: a list with the elements `items`
(diagnosis of each dataset), `scenes`, `series`, `overlaps`, `contexts`
(tag sets used by the recommendation rules), `alerts` and, if
`suggest = TRUE`, `suggestions`.

## Details

Large rasters are not read in full: statistics are estimated from a
regular sample of cells.

Some thresholds can be changed with
[`options()`](https://rdrr.io/r/base/options.html):

- `rsguide.min_multispectral_bands` (default 4): minimum number of
  spectral bands for the data to be considered multispectral;

- `rsguide.min_dates_long_series` (default 10): minimum number of dates
  for a time series to allow trend analysis;

- `rsguide.sample_size` (default 100000): number of cells sampled.

## Examples

``` r
r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
                 extent = terra::ext(500000, 500200, 9150000, 9150200))
terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
names(r) <- c("B2", "B3", "B4", "B8")
diagnose(r)
#> ══ rsguide diagnosis ═══════════════════════════════════════════════════════════
#> Inputs: 1 raster
#> 
#> ── R1 · r (raster) ─────────────────────────────────────────────────────────────
#> • Layers: 4 | Dimensions: 20 rows × 20 columns | Resolution: 10 m
#> • CRS: WGS 84 / UTM zone 18S (EPSG:32718)
#> • Extent: x from 500,000 to 500,200; y from 9,150,000 to 9,150,200
#> • Likely sensor: Sentinel-2 (MSI) (low confidence)
#> • Bands: B2 = blue; B3 = green; B4 = red; B8 = near infrared
#> • Value scale: scaled integers (reflectance x 10,000)
#> • Values: minimum 100, maximum 3,999
#> • NA (no data): 0.0% in the layer with most NA
#> 
#> ── Alerts ──────────────────────────────────────────────────────────────────────
#> ! [R1] The band names match more than one sensor (Sentinel-2 (MSI), Landsat 8/9 (OLI/TIRS)). I assumed Sentinel-2 (MSI); if that is wrong, use diagnose(..., sensor = "landsat89").
#> i [R1] Values look like reflectance x 10,000. For indices such as EVI and SAVI, convert first: r / 10000. Note: Sentinel-2 L2A images processed since 2022-01-25 have a -1000 offset [reflectance = (value - 1000) / 10000]; some providers already remove it, check yours.
#> 
#> ══ Suggested analyses (6) ══════════════════════════════════════════════════════
#> Vegetation indices
#>   • NDVI (Normalized Difference Vegetation Index) [ndvi] → 'r'
#>   • EVI (Enhanced Vegetation Index) [evi] → 'r'
#>   • SAVI (Soil-Adjusted Vegetation Index) [savi] → 'r'
#> Water
#>   • NDWI (Normalized Difference Water Index, McFeeters) [ndwi] → 'r'
#> Classification
#>   • Supervised land use and land cover classification [supervised_class] → 'r'
#>   • Unsupervised classification (clustering) [unsupervised_class] → 'r'
#> 
#> i Rationale and caveats: summary(). Example code: show_code(..., "ndvi"). Table to export: as.data.frame().
```
