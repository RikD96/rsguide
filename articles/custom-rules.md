# Writing your own rules

rsguide’s suggestions are not hard-coded in the package: they come from
a **rules table**. This lets you add new analyses (an index you use
often, a method from your lab) by writing one row in the table and,
optionally, a code template.

``` r

library(rsguide)
```

## How rsguide decides what to suggest

There are three steps:

1.  **Diagnosis.**
    [`diagnose()`](https://rikd96.github.io/rsguide/reference/diagnose.md)
    describes the data and summarizes what it found as **tags**:
    `band:red`, `band:nir`, `dem`, `time_series`, `vector:points`,
    `overlap`…
2.  **Rules.** Each rule has a **condition** written with these tags. If
    the condition is true, the analysis is suggested.
3.  **Code.** The analysis’ code template is filled in with the names of
    your files and bands.

Tags are computed for each **context**: each image (or set of bands from
the same scene), each time series, each vector and each image-vector
combination. Here are the contexts of an example:

``` r

folder <- system.file("extdata", package = "rsguide")
d <- diagnose(folder)

for (cx in d$contexts) {
  cat(cx$id, "-", cx$label, "\n  ", paste(cx$tags, collapse = ", "), "\n")
}
#> SC1 - 'jurua_dem_copernicus' 
#>    raster, scale:elevation, dem 
#> SC2 - 'jurua_s2_20190816' 
#>    raster, band:blue, band:green, band:red, band:rededge, band:nir, band:swir1, band:swir2, scale:int_10000, multispectral 
#> SC3 - 'jurua_s2_20240814' 
#>    raster, band:blue, band:green, band:red, band:rededge, band:nir, band:swir1, band:swir2, scale:int_10000, multispectral 
#> S1 - time series with 2 dates 
#>    raster, time_series, band:blue, band:green, band:red, band:rededge, band:nir, band:swir1, band:swir2, multispectral 
#> T1 - 'jurua_plots' 
#>    vector, vector:points, table 
#> SC1+T1 - 'jurua_dem_copernicus' + 'jurua_plots' 
#>    raster, scale:elevation, dem, vector, vector:points, table, overlap, crs_mismatch 
#> SC2+T1 - 'jurua_s2_20190816' + 'jurua_plots' 
#>    raster, band:blue, band:green, band:red, band:rededge, band:nir, band:swir1, band:swir2, scale:int_10000, multispectral, vector, vector:points, table, overlap, crs_mismatch 
#> SC3+T1 - 'jurua_s2_20240814' + 'jurua_plots' 
#>    raster, band:blue, band:green, band:red, band:rededge, band:nir, band:swir1, band:swir2, scale:int_10000, multispectral, vector, vector:points, table, overlap, crs_mismatch
```

## Available tags

| Tag | When it appears |
|----|----|
| `raster`, `vector`, `table` | type of data |
| `band:coastal`, `band:blue`, `band:green`, `band:red`, `band:rededge`, `band:nir`, `band:swir1`, `band:swir2`, `band:thermal`, `band:quality` | band identified |
| `multispectral` | 4 or more spectral bands (option `rsguide.min_multispectral_bands`) |
| `dem` | raster that looks like a digital elevation model |
| `scale:reflectance_0_1`, `scale:int_10000`, `scale:landsat_c2`, `scale:int_8bit`, `scale:index`, `scale:categorical`, `scale:elevation`, `scale:unknown` | value scale |
| `time_series` | images of the same area on 2 or more dates |
| `long_series` | series with 10 or more dates (option `rsguide.min_dates_long_series`) |
| `vector:points`, `vector:lines`, `vector:polygons` | vector geometry |
| `vector:labeled` | vector with a class column (text with few categories) |
| `overlap` | the vector falls, at least partly, inside the raster |
| `crs_mismatch` | raster and vector in different coordinate reference systems |

## Writing conditions

A condition combines tags with three operators:

| Operator | Meaning | Example                                              |
|----------|---------|------------------------------------------------------|
| `&`      | and     | `band:red & band:nir`                                |
| **\|**   | or      | band:green & band:nir **\|** band:green & band:swir1 |
| `!`      | not     | `multispectral & !time_series`                       |

`&` is evaluated before `|`, so `a & b | c` means “(a and b) or c”.
There are no parentheses: for more complex conditions, spell out the
alternatives separated by `|`.

You can test a condition against the tags of a context with the internal
function `eval_condition()`:

``` r

tags <- d$contexts$SC2$tags
rsguide:::eval_condition("band:green & band:nir", tags)
#> [1] TRUE
rsguide:::eval_condition("dem | time_series", tags)
#> [1] FALSE
```

If a condition uses a tag that does not exist (a typo, for example),
rsguide warns you:

``` r

bad <- data.frame(
  id = "test", analysis = "Test", category = "Test",
  condition = "band:reed & band:nir",
  rationale = "-", caveats = "-", packages = "terra"
)
rules <- rsguide:::validate_rules(bad)
#> Warning: Unknown tags in the conditions: "band:reed".
#> ℹ These rules will never be suggested. See the valid tags in `?rsguide_rules`.
```

## The table columns

Here is the table shipped with the package:

``` r

rules <- rsguide_rules()
names(rules)
#> [1] "id"        "analysis"  "category"  "condition" "rationale" "caveats"   "packages"
rules[rules$id == "ndvi", ]
#>     id                                      analysis           category
#> 1 ndvi NDVI (Normalized Difference Vegetation Index) Vegetation indices
#>             condition
#> 1 band:red & band:nir
#>                                                                                                                                                                            rationale
#> 1 Healthy vegetation strongly reflects near infrared and absorbs red light. NDVI uses this contrast to indicate how much green vegetation each pixel contains (values from -1 to 1).
#>                                                                                                                                                                                                                        caveats
#> 1 Use surface reflectance (atmospherically corrected imagery, level L2A/L2) | Mask clouds and shadows first | In dense forests, such as the Amazon, NDVI saturates: it stays close to 1 and stops discriminating; consider EVI
#>   packages
#> 1    terra
```

| Column | Content |
|----|----|
| `id` | short, unique identifier without spaces (e.g. `gndvi`) |
| `analysis` | name of the analysis, as shown to the user |
| `category` | group under which the analysis is listed (e.g. `Vegetation indices`) |
| `condition` | when to suggest it (see above) |
| `rationale` | why the analysis is possible with these data, in plain language |
| `caveats` | assumptions and precautions, separated by a vertical bar (**\|**) |
| `packages` | suggested R packages, separated by `;` |
| `template` | *optional*: path to an `.R` file with the code template |

## Adding a rule

### From R

Build a `data.frame` with the same columns and bind it to the package
table:

``` r

gndvi <- data.frame(
  id = "gndvi",
  analysis = "GNDVI (Green NDVI)",
  category = "Vegetation indices",
  condition = "band:green & band:nir",
  rationale = paste(
    "Uses the green band instead of red. It is more sensitive to chlorophyll",
    "concentration and saturates less than NDVI in dense vegetation."
  ),
  caveats = "Use surface reflectance | Mask clouds and shadows",
  packages = "terra"
)
my_rules <- rbind(rules, gndvi)

img <- file.path(folder, "jurua_s2_20240814.tif")
d <- diagnose(img, rules = my_rules)
d$suggestions[d$suggestions$id == "gndvi", c("analysis", "applies_to")]
#>              analysis          applies_to
#> 11 GNDVI (Green NDVI) 'jurua_s2_20240814'
```

To use **only** your rules, pass just your `data.frame`:
`diagnose(img, rules = gndvi)`.

### From a spreadsheet

If you prefer editing in a spreadsheet:

1.  Copy the package table to a folder of yours:

    ``` r

    file.copy(system.file("rules", "rules.csv", package = "rsguide"), "my_rules.csv")
    ```

2.  Open `my_rules.csv` in Excel, LibreOffice or Google Sheets, add or
    edit rows and save it as CSV. Comma or semicolon separators work, as
    do the UTF-8 and latin1 encodings.

3.  Use the file directly:

    ``` r

    d <- diagnose("my_images/", rules = "my_rules.csv")
    ```

## Writing a code template

Without a template the analysis is still suggested, but
[`show_code()`](https://rikd96.github.io/rsguide/reference/show_code.md)
will have nothing to show. A template is a regular `.R` file with
**placeholders** in braces, which rsguide replaces with the user’s data:

| Placeholder | Replaced by |
|----|----|
| `{load_raster:img}` | line(s) that read the raster into the object `img` (the name after `:` is free) |
| `{load_vector:points}` | line(s) that read the vector (or the table with coordinates) into the object `points` |
| `{load_series:imgs}` | lines that create the list `imgs`, with one image per date |
| `{scale}` | line that converts `img` to 0-1 reflectance, according to the detected scale |
| `{conversion}` | the same conversion, as an expression of `x` (useful inside functions) |
| `{blue}`, `{green}`, `{red}`, `{rededge}`, `{nir}`, `{swir1}`, `{swir2}`, `{thermal}`, `{coastal}` | name of the corresponding layer in the raster |
| `{index_expr}`, `{index_name}` | NDVI expression as a function of `x` (or the first layer, if there is no red and NIR) and its name |
| `{dates}` | vector of dates of the series, as `as.Date(c(...))` |
| `{class_column}` | class column of the vector (for training samples) |

The NDVI template, for example:

``` r

cat(readLines(system.file("templates", "ndvi.R", package = "rsguide")), sep = "\n")
#> # NDVI = (NIR - red) / (NIR + red)
#> {load_raster:img}
#> {scale}
#> ndvi <- (img[["{nir}"]] - img[["{red}"]]) / (img[["{nir}"]] + img[["{red}"]])
#> names(ndvi) <- "NDVI"
#> terra::plot(ndvi, main = "NDVI")
#> # terra::writeRaster(ndvi, "ndvi.tif")
```

Let’s write the GNDVI template and point to it in the `template` column:

``` r

template <- tempfile(fileext = ".R")  # use a path of yours, e.g. "templates/gndvi.R"
writeLines(c(
  "# GNDVI = (NIR - green) / (NIR + green)",
  "{load_raster:img}",
  "{scale}",
  "gndvi <- (img[[\"{nir}\"]] - img[[\"{green}\"]]) / (img[[\"{nir}\"]] + img[[\"{green}\"]])",
  "terra::plot(gndvi, main = \"GNDVI\")"
), template)

gndvi$template <- template
rules$template <- NA
d <- diagnose(img, rules = rbind(rules, gndvi))
show_code(d, "gndvi")
#> ── GNDVI (Green NDVI) - 'jurua_s2_20240814' ──────────────────────────────────────────────
#> # GNDVI = (NIR - green) / (NIR + green)
#> img <- terra::rast("/home/runner/work/_temp/Library/rsguide/extdata/jurua_s2_20240814.tif")
#> img <- (img - 1000) / 10000  # removes the offset and converts to 0-1 reflectance
#> gndvi <- (img[["B08"]] - img[["B03"]]) / (img[["B08"]] + img[["B03"]])
#> terra::plot(gndvi, main = "GNDVI")
```

Note that rsguide already added the `(img - 1000) / 10000` conversion,
because it detected the Sentinel-2 offset in this image.

## Tips

- **One analysis per row.** If the same analysis works with different
  band combinations, use `|` in the condition instead of repeating the
  row.
- **No repetition.** When a rule holds for the image alone, rsguide does
  not repeat it for “image + points” or for the time series that
  contains the image. That is why NDVI appears once per image, and point
  extraction only appears in the context that includes the points.
- **Useful caveats.** Write caveats as actions (“resample SWIR to 10 m”)
  rather than generic warnings.
- **Adjusting thresholds.** To change the number of dates that makes a
  long series or the number of bands that makes multispectral data, use
  `options(rsguide.min_dates_long_series = ...)` and
  `options(rsguide.min_multispectral_bands = ...)`.

## Contributing to the package

To include a rule in rsguide itself, and not only in your copy:

1.  add the row to `inst/rules/rules.csv`;
2.  write the template in `inst/templates/<id>.R`; rsguide finds it by
    `id`, with no need for the `template` column;
3.  add a test to `tests/testthat/test-rules.R` with synthetic data that
    trigger the rule. The test “the generated code for every suggestion
    runs without errors” runs your template automatically;
4.  run `devtools::check()`.
