# Orientação das vertentes (0 = norte, 90 = leste, 180 = sul, 270 = oeste)
{carregar_raster:mde}
orientacao <- terra::terrain(mde, v = "aspect", unit = "degrees")
terra::plot(orientacao, main = "Orientação (graus a partir do norte)")
