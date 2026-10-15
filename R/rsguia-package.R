#' rsguia: diagnóstico de dados de sensoriamento remoto e sugestão de análises
#'
#' O rsguia recebe dados de sensoriamento remoto, identifica automaticamente
#' o que eles são e sugere quais análises são possíveis. Cada sugestão vem
#' com uma justificativa em linguagem simples, os cuidados necessários e um
#' exemplo de código já preenchido com os seus arquivos e bandas. O pacote
#' **não executa** as análises: ele diagnostica e recomenda.
#'
#' @section Fluxo de uso:
#' 1. [diagnosticar()] recebe os dados (arquivos, pastas ou objetos do R) e
#'    descreve cada um: tipo, camadas, resolução, sistema de coordenadas,
#'    bandas e sensor, escala dos valores, MDE, séries temporais e
#'    sobreposição entre raster e vetor. Em seguida chama
#'    [sugerir_analises()].
#' 2. `print()` mostra o diagnóstico, os alertas e a lista de análises
#'    sugeridas.
#' 3. [summary()][summary.rsguia_diagnostico()] mostra a justificativa, os
#'    cuidados e os pacotes de cada análise.
#' 4. [ver_codigo()] mostra o código de exemplo, pronto para copiar.
#' 5. [as.data.frame()][as.data.frame.rsguia_diagnostico()] exporta o
#'    relatório como tabela.
#'
#' @section Entradas aceitas:
#' * Rasters: arquivos `.tif`, `.tiff`, `.vrt`, `.img`, `.jp2`, `.nc`,
#'   `.grd`, `.asc` ou objetos `SpatRaster` (terra).
#' * Vetores: arquivos `.shp`, `.gpkg`, `.geojson`, `.json`, `.kml` ou
#'   objetos `sf`, `sfc` e `SpatVector`.
#' * Tabelas com coordenadas: arquivos `.csv`, `.txt`, `.tsv` (separados por
#'   vírgula, ponto e vírgula ou tabulação) ou `data.frame`s. Colunas
#'   reconhecidas: `lon`/`lat`, `long`/`lat`, `lng`/`lat`,
#'   `longitude`/`latitude`, `decimalLongitude`/`decimalLatitude` (GBIF),
#'   `x`/`y`, `easting`/`northing`, `utm_x`/`utm_y`, entre outras.
#' * Pastas: todos os arquivos reconhecidos dentro da pasta.
#' * Várias entradas ao mesmo tempo: `diagnosticar(imagem, pontos)`.
#'
#' @section Sensores e bandas reconhecidos:
#' * Sentinel-2: `B1`/`B01` a `B12`, `B8A`, `SCL`, inclusive dentro de nomes
#'   de arquivo como `..._B04_10m.jp2`.
#' * Landsat 8/9 (Coleção 2): `SR_B1` a `SR_B7`, `ST_B10`, `QA_PIXEL` e os
#'   nomes curtos `B1` a `B11`.
#' * Landsat 4-7 (Coleção 2): `SR_B1` a `SR_B5`, `SR_B7`, `ST_B6`.
#' * Nomes genéricos, em inglês ou português: `blue`/`azul`,
#'   `green`/`verde`, `red`/`vermelho`, `rededge`, `nir`, `swir1`, `swir2`,
#'   `thermal`, além dos nomes usados em catálogos STAC (`nir08`, `swir16`,
#'   `swir22`...).
#'
#' A correspondência fica em `system.file("regras", "bandas.csv", package =
#' "rsguia")`. Quando os nomes servem para mais de um sensor, o pacote avisa;
#' informe o sensor com `diagnosticar(x, sensor = "landsat89")`.
#'
#' @section Opções:
#' * `rsguia.min_bandas_multiespectral` (padrão 4): número mínimo de bandas
#'   espectrais para considerar o dado multiespectral.
#' * `rsguia.min_datas_serie_longa` (padrão 10): número mínimo de datas para
#'   sugerir análise de tendência.
#' * `rsguia.tamanho_amostra` (padrão 100000): número de células lidas para
#'   estimar as estatísticas de rasters grandes.
#'
#' @section Para saber mais:
#' * `vignette("estudo-de-caso-jurua", package = "rsguia")`: estudo de caso
#'   com imagens Sentinel-2 do rio Juruá (AC).
#' * `vignette("criando-regras", package = "rsguia")`: como acrescentar
#'   análises novas à tabela de regras.
#' * [regras_rsguia()]: a tabela de regras e as etiquetas disponíveis.
#' * [dados_jurua]: os dados de exemplo.
#'
#' @keywords package
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end

## mockable bindings: start
## mockable bindings: end
NULL
