# Métricas de paisagem por classe (pacote landscapemetrics)
{carregar_raster:mapa}
landscapemetrics::check_landscape(mapa)  # confere CRS, unidades e tipo de dado
metricas <- landscapemetrics::calculate_lsm(
  mapa,
  what = c("lsm_c_pland", "lsm_c_np", "lsm_c_area_mn", "lsm_c_ed")
)
# pland = % da paisagem ocupada pela classe; np = número de fragmentos;
# area_mn = área média dos fragmentos (ha); ed = densidade de borda (m/ha)
tabela <- stats::reshape(as.data.frame(metricas[, c("class", "metric", "value")]),
                         idvar = "class", timevar = "metric", direction = "wide")
tabela
