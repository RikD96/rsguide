# Changelog

## rsguide 0.1.0

First release.

- [`diagnose()`](https://rikd96.github.io/rsguide/reference/diagnose.md)
  identifies rasters, vectors and tables with coordinates; recognizes
  bands and sensor (Sentinel-2, Landsat 4-9, generic names), the value
  scale (including the +1000 offset of Sentinel-2), DEMs, class maps,
  time series and raster/vector overlap.
- [`suggest_analyses()`](https://rikd96.github.io/rsguide/reference/suggest_analyses.md)
  matches the diagnosis against an editable table of 19 rules
  ([`rsguide_rules()`](https://rikd96.github.io/rsguide/reference/rsguide_rules.md))
  and suggests analyses with rationale, caveats, packages and example
  code already filled in
  ([`show_code()`](https://rikd96.github.io/rsguide/reference/show_code.md)).
- [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html) and
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) to read
  and export the report.
- Example data from the Jurua River (Acre, Brazil) and two vignettes: a
  case study and how to write custom rules.
