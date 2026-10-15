# Direção de fluxo, acumulação e rede de drenagem
{carregar_raster:mde}
# Antes, preencha depressões falsas (ex.: whitebox::wbt_fill_depressions())
direcao <- terra::terrain(mde, v = "flowdir")
acumulacao <- terra::flowAccumulation(direcao)
drenagem <- acumulacao > 100  # células que recebem água de mais de 100 outras; ajuste
terra::plot(drenagem, main = "Rede de drenagem")
# Bacia de um ponto de saída (exutório), em coordenadas do CRS do MDE:
# bacia <- terra::watershed(direcao, pourpoint = cbind(x, y))
