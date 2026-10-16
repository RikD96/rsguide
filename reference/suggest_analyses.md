# Suggest analyses from a diagnosis

Matches the characteristics found by
[`diagnose()`](https://rikd96.github.io/rsguide/reference/diagnose.md)
against the rules table
([`rsguide_rules()`](https://rikd96.github.io/rsguide/reference/rsguide_rules.md))
and lists the possible analyses, each with a rationale, caveats,
suggested packages and an example code snippet already filled in with
your file and band names. The analyses are not run.

## Usage

``` r
suggest_analyses(diagnosis, rules = NULL)
```

## Arguments

- diagnosis:

  An object of class `rsguide_diagnosis`.

- rules:

  Optional. A `data.frame` of rules or the path to a CSV file; see
  [`rsguide_rules()`](https://rikd96.github.io/rsguide/reference/rsguide_rules.md).

## Value

The same diagnosis, with the element `suggestions` (a `data.frame` with
one row per analysis and dataset it applies to).

## Details

You usually don't need to call this function:
[`diagnose()`](https://rikd96.github.io/rsguide/reference/diagnose.md)
already does it (argument `suggest = TRUE`). Use it to redo the
suggestions with other rules.

## Examples

``` r
r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
                 extent = terra::ext(500000, 500200, 9150000, 9150200))
terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
names(r) <- c("B2", "B3", "B4", "B8")
d <- diagnose(r, suggest = FALSE)
d <- suggest_analyses(d)
d$suggestions[, c("analysis", "applies_to")]
#>                                              analysis applies_to
#> 1       NDVI (Normalized Difference Vegetation Index)        'r'
#> 2                     EVI (Enhanced Vegetation Index)        'r'
#> 3               SAVI (Soil-Adjusted Vegetation Index)        'r'
#> 4 NDWI (Normalized Difference Water Index, McFeeters)        'r'
#> 5   Supervised land use and land cover classification        'r'
#> 6            Unsupervised classification (clustering)        'r'
```
