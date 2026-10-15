# rsguide

**Diagnose remote sensing data and suggest analyses.**

rsguide takes remote sensing data (satellite images, elevation models,
points, polygons or tables with coordinates), automatically identifies what
they are and suggests which analyses are possible. Each suggestion comes
with a plain-language rationale, the necessary caveats and an example code
snippet already filled in with your files and bands.

The package **does not run** the analyses: it diagnoses and recommends. It
is aimed at ecologists and students who are new to remote sensing.

## Installation

```r
# install.packages("remotes")
remotes::install_github("RikD96/rsguide", build_vignettes = TRUE)
```

## Example

```r
library(rsguide)

# A file, an R object or a whole folder
folder <- system.file("extdata", package = "rsguide")
d <- diagnose(folder)
d                     # diagnosis and list of suggested analyses
summary(d)            # rationale and caveats of each analysis
show_code(d, "ndvi")  # code ready to copy
as.data.frame(d)      # report as a table (to save as CSV)
```

What `diagnose()` identifies:

* type of data: raster, vector (points, lines, polygons) or table with
  coordinates (`lon`/`lat`, `x`/`y`, `decimalLongitude`/`decimalLatitude`...);
* layers, resolution, coordinate reference system, extent and missing values;
* bands and likely sensor (Sentinel-2, Landsat 4-9 or generic names such as
  `red`, `nir`, `swir1`);
* value scale (0-1 reflectance, integers x 10,000, Landsat Collection 2,
  the +1000 offset of Sentinel-2...);
* digital elevation models, class maps and time series;
* whether vectors fall on the raster, and whether the coordinate systems
  match.

Analyses that can be suggested: NDVI, EVI, SAVI, NDRE, NDMI, NDWI, MNDWI,
NBR, supervised and unsupervised classification, change detection, trend
analysis, slope, aspect, watersheds and drainage, extraction of values at
points, zonal statistics and landscape metrics.

## Editable rules

Recommendations come from a table (`inst/rules/rules.csv`) where each row
is an analysis, with the condition under which it is suggested. Inspect it
with `rsguide_rules()` and add your own rules without touching the code:

```r
my_rules <- rbind(rsguide_rules(), new_rule)
diagnose(folder, rules = my_rules)
```

## Documentation

* `?rsguide`: package overview, accepted inputs and recognized sensors.
* `vignette("case-study-jurua", package = "rsguide")`: diagnosis of
  Sentinel-2 images of the Jurua River, near Cruzeiro do Sul (Acre,
  Brazil), from a single file to a folder with a time series, a DEM and
  field plots.
* `vignette("custom-rules", package = "rsguide")`: how to add new analyses,
  write conditions and code templates.
* `?jurua_data`: the example data and their sources.
