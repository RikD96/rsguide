# Change detection: difference in {index_name} between the first and last dates
{load_series:imgs}
dates <- {dates}
convert <- function(x) {conversion}
index <- function(x) {index_expr}
before <- index(convert(imgs[[1]]))
after <- index(convert(imgs[[length(imgs)]]))
if (!terra::compareGeom(before, after, stopOnError = FALSE)) after <- terra::resample(after, before)
change <- after - before
terra::plot(change, main = paste("{index_name}:", dates[length(dates)], "minus", dates[1]))
# Strongly negative values indicate loss (e.g. deforestation); positive values, gain
