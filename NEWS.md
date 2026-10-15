# rsguide 0.1.0

First release.

* `diagnose()` identifies rasters, vectors and tables with coordinates;
  recognizes bands and sensor (Sentinel-2, Landsat 4-9, generic names), the
  value scale (including the +1000 offset of Sentinel-2), DEMs, class maps,
  time series and raster/vector overlap.
* `suggest_analyses()` matches the diagnosis against an editable table of 19
  rules (`rsguide_rules()`) and suggests analyses with rationale, caveats,
  packages and example code already filled in (`show_code()`).
* `print()`, `summary()` and `as.data.frame()` to read and export the report.
* Example data from the Jurua River (Acre, Brazil) and two vignettes: a case
  study and how to write custom rules.
