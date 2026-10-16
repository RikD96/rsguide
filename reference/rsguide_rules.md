# Recommendation rules

Returns the rules table used by
[`suggest_analyses()`](https://rikd96.github.io/rsguide/reference/suggest_analyses.md).
Each row is an analysis, with the condition under which it is suggested,
the rationale, the caveats and the recommended R packages. Use this
function to inspect the rules or as a starting point for your own.

## Usage

``` r
rsguide_rules(file = NULL)
```

## Arguments

- file:

  Optional. Path to a CSV file with custom rules, separated by commas or
  semicolons, encoded in UTF-8 or latin1 (as saved by Excel). If
  omitted, the table shipped with the package is used
  (`system.file("rules", "rules.csv", package = "rsguide")`).

## Value

A `data.frame` with the rules.

## Details

Required columns:

- `id`: short, unique identifier (e.g. `"ndvi"`). The analysis' code
  template is looked up in `inst/templates/<id>.R`; custom rules can
  point to another file in the optional column `template`.

- `analysis`, `category`: name of the analysis and the group it belongs
  to.

- `condition`: expression using tags produced by
  [`diagnose()`](https://rikd96.github.io/rsguide/reference/diagnose.md),
  combined with `&` (and), `|` (or) and `!` (not). Example:
  `"band:green & band:nir | band:green & band:swir1"`.

- `rationale`: why the analysis is possible with these data.

- `caveats`: assumptions and precautions, separated by `|`.

- `packages`: suggested R packages, separated by `;`.

Available tags: `raster`, `vector`, `table`, `multispectral`, `dem`,
`time_series`, `long_series`, `overlap`, `crs_mismatch`, `band:<group>`
(`coastal`, `blue`, `green`, `red`, `rededge`, `nir`, `swir1`, `swir2`,
`thermal`, `quality`), `scale:<type>` (`reflectance_0_1`, `int_10000`,
`landsat_c2`, `int_8bit`, `index`, `categorical`, `elevation`,
`unknown`) and `vector:<type>` (`points`, `lines`, `polygons`,
`labeled`).

## Examples

``` r
rules <- rsguide_rules()
rules[, c("id", "analysis", "condition")]
#>                          id                                            analysis
#> 1                      ndvi       NDVI (Normalized Difference Vegetation Index)
#> 2                       evi                     EVI (Enhanced Vegetation Index)
#> 3                      savi               SAVI (Soil-Adjusted Vegetation Index)
#> 4                      ndre         NDRE (Normalized Difference Red Edge index)
#> 5                      ndmi         NDMI (Normalized Difference Moisture Index)
#> 6                      ndwi NDWI (Normalized Difference Water Index, McFeeters)
#> 7                     mndwi                               MNDWI (Modified NDWI)
#> 8                       nbr                NBR (Normalized Burn Ratio) and dNBR
#> 9          supervised_class   Supervised land use and land cover classification
#> 10 supervised_class_samples     Supervised classification with your own samples
#> 11       unsupervised_class            Unsupervised classification (clustering)
#> 12         change_detection                      Change detection between dates
#> 13                    trend                             Temporal trend analysis
#> 14                    slope                                               Slope
#> 15                   aspect                          Aspect (slope orientation)
#> 16               watersheds          Watershed and drainage network delineation
#> 17         point_extraction               Extraction of raster values at points
#> 18              zonal_stats                         Zonal statistics by polygon
#> 19        landscape_metrics                   Landscape metrics (fragmentation)
#>                                   condition
#> 1                       band:red & band:nir
#> 2           band:blue & band:red & band:nir
#> 3                       band:red & band:nir
#> 4                   band:rededge & band:nir
#> 5                     band:nir & band:swir1
#> 6                     band:green & band:nir
#> 7                   band:green & band:swir1
#> 8                     band:nir & band:swir2
#> 9                             multispectral
#> 10 multispectral & vector:labeled & overlap
#> 11                            multispectral
#> 12                              time_series
#> 13                time_series & long_series
#> 14                                      dem
#> 15                                      dem
#> 16                                      dem
#> 17         raster & vector:points & overlap
#> 18       raster & vector:polygons & overlap
#> 19                        scale:categorical

# Adding a custom rule
gndvi <- data.frame(
  id = "gndvi", analysis = "GNDVI", category = "Vegetation indices",
  condition = "band:green & band:nir",
  rationale = "Uses green instead of red; sensitive to chlorophyll.",
  caveats = "Use surface reflectance | Mask clouds", packages = "terra"
)
my_rules <- rbind(rules, gndvi)
```
