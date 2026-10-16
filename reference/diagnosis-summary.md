# Summarize and export a diagnosis

[`summary()`](https://rdrr.io/r/base/summary.html) shows an overview of
the data and the full list of suggested analyses, with rationale,
caveats and packages (and, if `code = TRUE`, the example code of each
one). [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
turns the report into a table, which can be saved with
[`utils::write.csv()`](https://rdrr.io/r/utils/write.table.html).

## Usage

``` r
# S3 method for class 'rsguide_diagnosis'
summary(object, code = FALSE, ...)

# S3 method for class 'rsguide_diagnosis'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  ...,
  type = c("suggestions", "items", "alerts")
)
```

## Arguments

- object, x:

  An object of class `rsguide_diagnosis`, created by
  [`diagnose()`](https://rikd96.github.io/rsguide/reference/diagnose.md).

- code:

  If `TRUE`, includes the example code of each analysis.

- ...:

  Ignored.

- row.names, optional:

  Ignored; present for compatibility with
  [`base::as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

- type:

  Which table to export: `"suggestions"` (one row per analysis and
  dataset), `"items"` (one row per diagnosed dataset) or `"alerts"`.

## Value

[`summary()`](https://rdrr.io/r/base/summary.html) returns an object of
class `summary.rsguide_diagnosis`;
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns a
`data.frame`.

## Examples

``` r
r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
                 extent = terra::ext(500000, 500200, 9150000, 9150200))
terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
names(r) <- c("B2", "B3", "B4", "B8")
d <- diagnose(r)
summary(d)
#> ══ rsguide diagnosis summary ═══════════════════════════════════════════════════
#> R1   r (raster) 
#>      4 layers · 10 m · EPSG:32718 · Sentinel-2 (MSI) · scaled integers
#>        (reflectance x 10,000)
#> Alerts: 1 warning(s) and 1 note(s); see print() or as.data.frame(..., type = "alerts").
#> 
#> ══ Suggested analyses (6) ══════════════════════════════════════════════════════
#> 
#> Vegetation indices
#> 1. NDVI (Normalized Difference Vegetation Index) [ndvi]
#>    Applies to: 'r'
#>    Why: Healthy vegetation strongly reflects near infrared and absorbs red
#>      light. NDVI uses this contrast to indicate how much green vegetation
#>      each pixel contains (values from -1 to 1).
#>    Caveats:
#>      - Use surface reflectance (atmospherically corrected imagery, level
#>        L2A/L2)
#>      - Mask clouds and shadows first
#>      - In dense forests, such as the Amazon, NDVI saturates: it stays close
#>        to 1 and stops discriminating; consider EVI
#>    Packages: terra
#> 2. EVI (Enhanced Vegetation Index) [evi]
#>    Applies to: 'r'
#>    Why: Similar to NDVI, but also uses the blue band to reduce atmospheric
#>      and soil effects. It saturates less in dense vegetation, which makes it
#>      popular in tropical forests.
#>    Caveats:
#>      - The formula only works with reflectance on a 0-1 scale: convert the
#>        values first
#>      - Mask clouds and shadows
#>      - Values far outside -1 to 1 point to scale problems or clouds
#>    Packages: terra
#> 3. SAVI (Soil-Adjusted Vegetation Index) [savi]
#>    Applies to: 'r'
#>    Why: A version of NDVI that reduces the influence of bare soil.
#>      Recommended where vegetation is sparse: degraded pastures, regenerating
#>      areas, grasslands and open savannas.
#>    Caveats:
#>      - The L factor (0.5 is the default) changes the result; use the same L
#>        for all images
#>      - Requires reflectance on a 0-1 scale
#>      - Mask clouds and shadows
#>    Packages: terra
#> 
#> Water
#> 4. NDWI (Normalized Difference Water Index, McFeeters) [ndwi]
#>    Applies to: 'r'
#>    Why: Water reflects green light and absorbs almost all near infrared. NDWI
#>      highlights rivers, lakes and flooded areas; positive values usually
#>      indicate water.
#>    Caveats:
#>      - Built-up areas and bare soil can also have high values; MNDWI
#>        separates them better
#>      - The water/non-water threshold (e.g. 0) varies between scenes: check it
#>        on the image
#>      - Sediment-laden rivers (such as the Jurua) reflect more and may get
#>        lower values
#>    Packages: terra
#> 
#> Classification
#> 5. Supervised land use and land cover classification [supervised_class]
#>    Applies to: 'r'
#>    Why: With several bands, each cover type (forest, pasture, water, urban)
#>      has its own spectral signature. You provide examples of each class and
#>      an algorithm (e.g. Random Forest) classifies the rest of the image.
#>    Caveats:
#>      - Requires labeled training samples (points or polygons for each class)
#>      - Validate with independent samples (confusion matrix, accuracy)
#>      - Mask clouds and use images from the same date or season
#>    Packages: terra; sf; randomForest
#> 6. Unsupervised classification (clustering) [unsupervised_class]
#>    Applies to: 'r'
#>    Why: The algorithm (e.g. k-means) groups similar pixels without training
#>      samples. It is a good first exploration of the landscape.
#>    Caveats:
#>      - Clusters have no names: you interpret what each one represents
#>      - The number of clusters is your choice; try a few values
#>      - Clouds and shadows form their own clusters
#>    Packages: terra
#> 
#> i To see the code: show_code(..., "ndvi") or summary(..., code = TRUE).
report <- as.data.frame(d)
report[, c("analysis", "packages")]
#>                                              analysis                packages
#> 1       NDVI (Normalized Difference Vegetation Index)                   terra
#> 2                     EVI (Enhanced Vegetation Index)                   terra
#> 3               SAVI (Soil-Adjusted Vegetation Index)                   terra
#> 4 NDWI (Normalized Difference Water Index, McFeeters)                   terra
#> 5   Supervised land use and land cover classification terra; sf; randomForest
#> 6            Unsupervised classification (clustering)                   terra
as.data.frame(d, type = "items")
#>   id name   type source layers features geometry resolution_m
#> 1 R1    r raster   <NA>      4       NA     <NA>           10
#>                                  crs  epsg           sensor sensor_confidence
#> 1 WGS 84 / UTM zone 18S (EPSG:32718) 32718 Sentinel-2 (MSI)               low
#>                               bands     scale   dem dates max_prop_na
#> 1 B2=blue; B3=green; B4=red; B8=nir int_10000 FALSE  <NA>           0
#>                                                                                description
#> 1 4 layers · 10 m · EPSG:32718 · Sentinel-2 (MSI) · scaled integers (reflectance x 10,000)

# Saving the report as CSV (here to a temporary file)
file <- tempfile(fileext = ".csv")
utils::write.csv(report, file, row.names = FALSE)
unlink(file)
```
