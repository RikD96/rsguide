# Class-level landscape metrics (landscapemetrics package)
{load_raster:land_map}
landscapemetrics::check_landscape(land_map)  # checks CRS, units and data type
metrics <- landscapemetrics::calculate_lsm(
  land_map,
  what = c("lsm_c_pland", "lsm_c_np", "lsm_c_area_mn", "lsm_c_ed")
)
# pland = % of the landscape covered by the class; np = number of patches;
# area_mn = mean patch area (ha); ed = edge density (m/ha)
table_wide <- stats::reshape(as.data.frame(metrics[, c("class", "metric", "value")]),
                             idvar = "class", timevar = "metric", direction = "wide")
table_wide
