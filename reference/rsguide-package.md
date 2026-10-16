# rsguide: diagnosis of remote sensing data and suggestion of analyses

rsguide takes remote sensing data, automatically identifies what they
are and suggests which analyses are possible. Each suggestion comes with
a plain-language rationale, the necessary caveats and an example code
snippet already filled in with your files and bands. The package does
**not run** the analyses: it diagnoses and recommends.

## Workflow

1.  [`diagnose()`](https://rikd96.github.io/rsguide/reference/diagnose.md)
    takes the data (files, folders or R objects) and describes each one:
    type, layers, resolution, coordinate reference system, bands and
    sensor, value scale, DEM, time series and raster/vector overlap. It
    then calls
    [`suggest_analyses()`](https://rikd96.github.io/rsguide/reference/suggest_analyses.md).

2.  [`print()`](https://rdrr.io/r/base/print.html) shows the diagnosis,
    the alerts and the list of suggested analyses.

3.  [summary()](https://rikd96.github.io/rsguide/reference/diagnosis-summary.md)
    shows the rationale, caveats and packages of each analysis.

4.  [`show_code()`](https://rikd96.github.io/rsguide/reference/show_code.md)
    prints the example code, ready to copy.

5.  [as.data.frame()](https://rikd96.github.io/rsguide/reference/diagnosis-summary.md)
    exports the report as a table.

## Accepted inputs

- Rasters: `.tif`, `.tiff`, `.vrt`, `.img`, `.jp2`, `.nc`, `.grd`,
  `.asc` files or `SpatRaster` objects (terra).

- Vectors: `.shp`, `.gpkg`, `.geojson`, `.json`, `.kml` files or `sf`,
  `sfc` and `SpatVector` objects.

- Tables with coordinates: `.csv`, `.txt`, `.tsv` files (separated by
  commas, semicolons or tabs) or `data.frame`s. Recognized columns:
  `lon`/`lat`, `long`/`lat`, `lng`/`lat`, `longitude`/`latitude`,
  `decimalLongitude`/`decimalLatitude` (GBIF), `x`/`y`,
  `easting`/`northing`, `utm_x`/`utm_y`, among others.

- Folders: every recognized file inside the folder.

- Several inputs at once: `diagnose(image, points)`.

## Recognized sensors and bands

- Sentinel-2: `B1`/`B01` to `B12`, `B8A`, `SCL`, also inside file names
  such as `..._B04_10m.jp2`.

- Landsat 8/9 (Collection 2): `SR_B1` to `SR_B7`, `ST_B10`, `QA_PIXEL`
  and the short names `B1` to `B11`.

- Landsat 4-7 (Collection 2): `SR_B1` to `SR_B5`, `SR_B7`, `ST_B6`.

- Generic names: `blue`, `green`, `red`, `rededge`, `nir`, `swir1`,
  `swir2`, `thermal`, the names used in STAC catalogs (`nir08`,
  `swir16`, `swir22`, ...) and their Portuguese equivalents (`azul`,
  `verde`, `vermelho`, ...).

The aliases are listed in
`system.file("rules", "bands.csv", package = "rsguide")`. When the names
match more than one sensor, the package warns you; set the sensor with
`diagnose(x, sensor = "landsat89")`.

## Options

- `rsguide.min_multispectral_bands` (default 4): minimum number of
  spectral bands for the data to be considered multispectral.

- `rsguide.min_dates_long_series` (default 10): minimum number of dates
  to suggest trend analysis.

- `rsguide.sample_size` (default 100000): number of cells read to
  estimate statistics of large rasters.

## Learn more

- [`vignette("case-study-jurua", package = "rsguide")`](https://rikd96.github.io/rsguide/articles/case-study-jurua.md):
  case study with Sentinel-2 images of the Jurua River (Acre, Brazil).

- [`vignette("custom-rules", package = "rsguide")`](https://rikd96.github.io/rsguide/articles/custom-rules.md):
  how to add new analyses to the rules table.

- [`rsguide_rules()`](https://rikd96.github.io/rsguide/reference/rsguide_rules.md):
  the rules table and the available tags.

- [jurua_data](https://rikd96.github.io/rsguide/reference/jurua_data.md):
  the example data.

## See also

Useful links:

- <https://rikd96.github.io/rsguide/>

- <https://github.com/RikD96/rsguide>

- Report bugs at <https://github.com/RikD96/rsguide/issues>

## Author

**Maintainer**: Henrique Paulo <mundo.virais@gmail.com> \[copyright
holder\]

Authors:

- Henrique Paulo <mundo.virais@gmail.com> \[copyright holder\]
