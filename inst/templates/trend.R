# Pixel-wise temporal trend of {index_name} (linear regression)
{load_series:imgs}
dates <- {dates}
convert <- function(x) {conversion}
index <- function(x) {index_expr}
series <- terra::rast(lapply(imgs, function(x) index(convert(x))))
time <- as.numeric(dates - min(dates)) / 365.25  # years since the first date
slope_per_year <- function(v) {
  ok <- !is.na(v)
  if (sum(ok) < 3) return(NA)
  stats::coef(stats::lm(v[ok] ~ time[ok]))[[2]]
}
trend <- terra::app(series, slope_per_year)
terra::plot(trend, main = "Trend in {index_name} (change per year)")
# Non-parametric alternative: Kendall::MannKendall() applied to each pixel
