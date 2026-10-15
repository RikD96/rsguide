#' Dados de exemplo: rio Juruá, Cruzeiro do Sul (AC)
#'
#' Arquivos de exemplo instalados com o pacote, usados na vignette e nos
#' exemplos. Cobrem um recorte de 2,5 × 2,5 km sobre um meandro do rio Juruá,
#' a várzea e parte da cidade de Cruzeiro do Sul, no Acre (centro
#' aproximado: 7,649° S, 72,654° O). Não são objetos do R: são arquivos,
#' acessados com [system.file()].
#'
#' @format Quatro arquivos na pasta `extdata` do pacote:
#' \describe{
#'   \item{`jurua_s2_20190816.tif`, `jurua_s2_20240814.tif`}{Recortes de
#'     imagens Sentinel-2 L2A (Coleção 1) de 16/08/2019 e 14/08/2024, ambas
#'     sem nuvens no recorte. Sete bandas a 10 m (`B02`, `B03`, `B04`,
#'     `B05`, `B08`, `B11`, `B12`; as de 20 m foram reamostradas pelo
#'     vizinho mais próximo), em UTM 18S (EPSG:32718). Valores inteiros
#'     originais do provedor: reflectância = (valor - 1000) / 10000.}
#'   \item{`jurua_mde_copernicus.tif`}{Modelo digital de elevação Copernicus
#'     GLO-30, reprojetado para UTM 18S a 30 m. Elevação em metros.}
#'   \item{`jurua_parcelas.csv`}{25 parcelas **fictícias**, sorteadas dentro
#'     do recorte, com as colunas `parcela`, `longitude` e `latitude` (graus
#'     decimais, WGS 84). Servem só para demonstração.}
#' }
#'
#' @source Earth Search (Element 84, AWS Open Data), coleções
#'   `sentinel-2-c1-l2a` e `cop-dem-glo-30`, acessadas em outubro de 2026.
#'   Dados Sentinel-2: Copernicus/ESA. MDE: Copernicus DEM, © DLR e Airbus.
#'   O script que gerou os arquivos está em `data-raw/jurua.R`, no
#'   repositório do pacote.
#'
#' @examples
#' pasta <- system.file("extdata", package = "rsguia")
#' list.files(pasta)
#'
#' img <- terra::rast(file.path(pasta, "jurua_s2_20240814.tif"))
#' terra::plotRGB((img - 1000) / 10000, r = "B04", g = "B03", b = "B02", stretch = "lin")
#'
#' @name dados_jurua
#' @keywords datasets
NULL
