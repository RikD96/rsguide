# Detecção de mudanças: diferença de {indice_nome} entre a primeira e a última data
{carregar_serie:imgs}
datas <- {datas}
converter <- function(x) {conversao}
indice <- function(x) {indice_expr}
antes <- indice(converter(imgs[[1]]))
depois <- indice(converter(imgs[[length(imgs)]]))
if (!terra::compareGeom(antes, depois, stopOnError = FALSE)) depois <- terra::resample(depois, antes)
mudanca <- depois - antes
terra::plot(mudanca, main = paste("{indice_nome}:", datas[length(datas)], "menos", datas[1]))
# Valores muito negativos indicam perda (ex.: desmatamento); positivos, ganho
