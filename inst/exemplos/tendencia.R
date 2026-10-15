# Tendência temporal do {indice_nome}, pixel a pixel (regressão linear)
{carregar_serie:imgs}
datas <- {datas}
converter <- function(x) {conversao}
indice <- function(x) {indice_expr}
serie <- terra::rast(lapply(imgs, function(x) indice(converter(x))))
tempo <- as.numeric(datas - min(datas)) / 365.25  # anos desde a primeira data
inclinacao <- function(v) {
  ok <- !is.na(v)
  if (sum(ok) < 3) return(NA)
  stats::coef(stats::lm(v[ok] ~ tempo[ok]))[[2]]
}
tendencia <- terra::app(serie, inclinacao)
terra::plot(tendencia, main = "Tendência do {indice_nome} (variação por ano)")
# Alternativa não paramétrica: Kendall::MannKendall() aplicado a cada pixel
