# Declividade a partir do MDE
{carregar_raster:mde}
declividade <- terra::terrain(mde, v = "slope", unit = "degrees")
terra::plot(declividade, main = "Declividade (graus)")
