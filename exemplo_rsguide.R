# =============================================================================
# Tour completo do pacote rsguide
# -----------------------------------------------------------------------------
# Este script chama o rsguide e passa por tudo o que o pacote faz:
#
#   1. diagnosticar uma imagem (sensor, bandas, escala, alertas);
#   2. ler o resumo com justificativas e cuidados de cada análise;
#   3. ver o código de exemplo pronto e EXECUTÁ-LO;
#   4. diagnosticar uma pasta inteira (série temporal, MDE, pontos de campo);
#   5. exportar o relatório em CSV;
#   6. diagnosticar objetos já carregados no R (SpatRaster, sf, data.frame);
#   7. forçar o sensor e informar o CRS de tabelas;
#   8. separar diagnóstico e sugestões (suggest = FALSE + suggest_analyses());
#   9. ver, editar e criar regras (com modelo de código próprio);
#  10. ajustar limiares com options() e destravar a análise de tendência;
#  11. classificação supervisionada com amostras rotuladas e métricas de
#      paisagem num mapa de classes;
#  12. rodar automaticamente o código de TODAS as sugestões e conferir.
#
# Como usar: abra no RStudio e rode tudo (Ctrl+Shift+Enter) ou, no terminal,
#   Rscript exemplo_rsguide.R
# Os arquivos gerados ficam na pasta "rsguide_resultados" (veja `saida`).
# =============================================================================

# -- 0. Preparação ------------------------------------------------------------

# Instale o pacote se ainda não tiver (versão do GitHub):
if (!requireNamespace("rsguide", quietly = TRUE)) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
  remotes::install_github("RikD96/rsguide")
}
# Pacotes opcionais usados por algumas das análises sugeridas
for (p in c("randomForest", "landscapemetrics")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}

library(rsguide)

saida <- file.path(getwd(), "rsguide_resultados")
dir.create(saida, showWarnings = FALSE)

# Fora do RStudio (Rscript), os gráficos vão para um PDF
if (!interactive()) pdf(file.path(saida, "graficos.pdf"), width = 7, height = 6)

titulo <- function(texto) cat("\n\n", cli::rule(left = texto, line = 2), "\n\n", sep = "")

# Roda o código gerado pelo rsguide num ambiente separado (para não
# sobrescrever objetos deste script) e mostra os resultados impressos
roda <- function(codigo) {
  source(exprs = parse(text = codigo), local = new.env(), print.eval = TRUE)
}

# Dados de exemplo que vêm com o pacote (rio Juruá, Cruzeiro do Sul, AC)
pasta <- system.file("extdata", package = "rsguide")
print(list.files(pasta))
img <- file.path(pasta, "jurua_s2_20240814.tif")


# -- 1. Diagnóstico de uma imagem --------------------------------------------
titulo("1. diagnose() de uma imagem Sentinel-2")

d <- diagnose(img)
d   # print(): sensor, bandas, escala (offset +1000), alertas e sugestões

# O objeto é uma lista; dá para olhar cada parte
names(d)
d$items$R1$sensor
d$items$R1$scale$description
d$alerts


# -- 2. Resumo completo ------------------------------------------------------
titulo("2. summary(): justificativa, cuidados e pacotes")

summary(d)
# Com o código de cada análise junto:
summary(d, code = TRUE)


# -- 3. Código pronto e execução ---------------------------------------------
titulo("3. show_code() e execução do código sugerido")

d$suggestions[, c("id", "analysis", "applies_to")]

codigo_ndvi <- show_code(d, "ndvi")       # imprime e devolve o texto
roda(codigo_ndvi)                         # roda: calcula e plota o NDVI

roda(show_code(d, "mndwi"))               # água (MNDWI)

show_code(d)                              # todas as sugestões de uma vez


# -- 4. Diagnóstico de uma pasta inteira -------------------------------------
titulo("4. diagnose() de uma pasta (série, MDE e parcelas)")

dd <- diagnose(pasta)
dd

dd$series      # série temporal 2019 -> 2024 encontrada pelas datas nos nomes
dd$overlaps    # parcelas caem dentro dos rasters?
for (cx in dd$contexts) {
  cat(cx$id, "-", cx$label, "\n   tags:", paste(cx$tags, collapse = ", "), "\n")
}

# Rodando algumas sugestões que só aparecem com vários arquivos
roda(show_code(dd, "change_detection"))  # mudança 2019 -> 2024
roda(show_code(dd, "slope"))             # declividade (MDE)
roda(show_code(dd, "aspect"))            # orientação (MDE)
roda(show_code(dd, "watersheds"))        # drenagem (MDE)
roda(show_code(dd, "point_extraction"))  # valores nas parcelas


# -- 5. Exportar o relatório -------------------------------------------------
titulo("5. as.data.frame() e exportação em CSV")

relatorio <- as.data.frame(dd)                    # uma linha por análise
arquivos  <- as.data.frame(dd, type = "items")    # uma linha por arquivo
alertas   <- as.data.frame(dd, type = "alerts")   # avisos e notas

head(relatorio[, c("analysis", "category", "files", "packages")])
arquivos[, c("id", "name", "type", "resolution_m", "sensor", "scale")]
alertas

utils::write.csv(relatorio, file.path(saida, "relatorio_sugestoes.csv"), row.names = FALSE)
utils::write.csv(arquivos,  file.path(saida, "relatorio_arquivos.csv"),  row.names = FALSE)
utils::write.csv(alertas,   file.path(saida, "relatorio_alertas.csv"),   row.names = FALSE)


# -- 6. Objetos já carregados no R -------------------------------------------
titulo("6. diagnose() com SpatRaster, sf e data.frame")

r      <- terra::rast(img)
mde    <- terra::rast(file.path(pasta, "jurua_dem_copernicus.tif"))
tabela <- utils::read.csv(file.path(pasta, "jurua_plots.csv"))
pontos <- sf::st_as_sf(tabela, coords = c("longitude", "latitude"), crs = 4326)

diagnose(r)                  # raster em memória
diagnose(pontos)             # vetor sf
diagnose(tabela)             # tabela: acha sozinho as colunas longitude/latitude
diagnose(r, mde, pontos)     # vários objetos juntos
diagnose(list(r, tabela))    # listas também valem


# -- 7. Forçar sensor e CRS da tabela ----------------------------------------
titulo("7. Argumentos sensor = e table_crs =")

# Bandas com nomes genéricos: o sensor não é reconhecido...
generico <- r
names(generico) <- paste0("band_", seq_len(terra::nlyr(generico)))
diagnose(generico)
# ...então informe o sensor (a ordem das bandas segue a do Sentinel-2)
diagnose(generico, sensor = "sentinel2")

# Tabela com coordenadas em UTM: diga o CRS
tabela_utm <- as.data.frame(sf::st_coordinates(sf::st_transform(pontos, 32718)))
tabela_utm$plot <- tabela$plot
diagnose(r, tabela_utm, table_crs = 32718)


# -- 8. Diagnóstico sem sugestões e sugestões depois -------------------------
titulo("8. suggest = FALSE + suggest_analyses()")

so_diag <- diagnose(img, suggest = FALSE)
is.null(so_diag$suggestions)
com_sug <- suggest_analyses(so_diag)
com_sug$suggestions[, c("id", "analysis")]


# -- 9. Regras: ver, criar e usar --------------------------------------------
titulo("9. rsguide_rules() e regras próprias")

regras <- rsguide_rules()
regras[, c("id", "condition")]

# Nova análise (GNDVI) com um modelo de código próprio
modelo <- file.path(saida, "gndvi_modelo.R")
writeLines(c(
  "# GNDVI = (NIR - green) / (NIR + green)",
  "{load_raster:img}",
  "{scale}",
  "gndvi <- (img[[\"{nir}\"]] - img[[\"{green}\"]]) / (img[[\"{nir}\"]] + img[[\"{green}\"]])",
  "terra::plot(gndvi, main = \"GNDVI\")"
), modelo)

regra_gndvi <- data.frame(
  id = "gndvi",
  analysis = "GNDVI (Green NDVI)",
  category = "Vegetation indices",
  condition = "band:green & band:nir",
  rationale = "Usa o verde no lugar do vermelho; mais sensível à clorofila.",
  caveats = "Use reflectância de superfície | Mascare nuvens e sombras",
  packages = "terra",
  template = modelo
)
regras$template <- NA
minhas_regras <- rbind(regras, regra_gndvi)

d_gndvi <- diagnose(img, rules = minhas_regras)
roda(show_code(d_gndvi, "gndvi"))

# Só as suas regras
diagnose(img, rules = regra_gndvi)$suggestions[, c("id", "analysis")]

# As regras também podem ficar num CSV (edite no Excel/LibreOffice)
csv_regras <- file.path(saida, "minhas_regras.csv")
utils::write.csv(minhas_regras, csv_regras, row.names = FALSE)
rsguide_rules(csv_regras)[, c("id", "condition")]
diagnose(img, rules = csv_regras)$suggestions$id


# -- 10. Limiares com options() e análise de tendência -----------------------
titulo("10. options(): série longa e análise de tendência")

# A tendência só é sugerida com 10+ datas. Criamos uma série SINTÉTICA de
# 6 datas (interpolando 2019 -> 2024, com ruído) só para demonstrar.
pasta_serie <- file.path(saida, "serie_sintetica")
dir.create(pasta_serie, showWarnings = FALSE)
i2019 <- terra::rast(file.path(pasta, "jurua_s2_20190816.tif"))
i2024 <- terra::rast(img)
set.seed(42)
for (k in 0:5) {
  w <- k / 5
  x <- round((1 - w) * i2019 + w * i2024 + stats::rnorm(1, 0, 20))
  names(x) <- names(i2024)
  terra::writeRaster(x, file.path(pasta_serie, sprintf("s2_%d0815.tif", 2019 + k)),
                     datatype = "INT2U", overwrite = TRUE)
}

diagnose(pasta_serie)$suggestions$id   # com 6 datas: sem "trend"

antigas <- options(rsguide.min_dates_long_series = 6)
d_serie <- diagnose(pasta_serie)
d_serie$suggestions$id                 # agora aparece "trend"
roda(show_code(d_serie, "trend"))
options(antigas)                       # volta ao padrão

# Outros limiares: rsguide.min_multispectral_bands e rsguide.sample_size
antigas <- options(rsguide.min_multispectral_bands = 8, rsguide.sample_size = 5000)
diagnose(img)$suggestions$id           # 7 bandas < 8: sem classificação
options(antigas)


# -- 11. Amostras rotuladas e mapa de classes --------------------------------
titulo("11. Classificação com amostras e métricas de paisagem")

# Amostras de treino: polígonos com uma coluna de classe. Aqui são geradas a
# partir de índices da própria imagem (água, vegetação, outros), só para o
# exemplo; no seu trabalho use amostras de campo ou de interpretação visual.
refl <- (i2024 - 1000) / 10000
ndvi  <- (refl$B08 - refl$B04) / (refl$B08 + refl$B04)
mndwi <- (refl$B03 - refl$B11) / (refl$B03 + refl$B11)
classes <- terra::ifel(mndwi > 0.1, 1, terra::ifel(ndvi > 0.6, 2, 3))
names(classes) <- "classe"
set.seed(1)
amostras <- terra::spatSample(classes, 20, method = "stratified", as.points = TRUE)
amostras <- sf::st_as_sf(amostras)
amostras$classe <- c("agua", "vegetacao", "outros")[amostras[[1]]]
amostras <- sf::st_buffer(amostras[, "classe"], 15)
arq_amostras <- file.path(saida, "amostras_treino.gpkg")
sf::st_write(amostras, arq_amostras, delete_dsn = TRUE, quiet = TRUE)

d_amostras <- diagnose(img, arq_amostras)
d_amostras$suggestions[, c("id", "applies_to")]
roda(show_code(d_amostras, "supervised_class_samples"))
roda(show_code(d_amostras, "zonal_stats"))   # polígonos -> estatística zonal

# Mapa de classes (categórico) -> métricas de paisagem
arq_mapa <- file.path(saida, "mapa_classes.tif")
terra::writeRaster(classes, arq_mapa, datatype = "INT1U", overwrite = TRUE)
d_mapa <- diagnose(arq_mapa)
d_mapa
roda(show_code(d_mapa, "landscape_metrics"))


# -- 12. Rodar o código de TODAS as sugestões --------------------------------
titulo("12. Executando automaticamente todas as sugestões")

roda_tudo <- function(diag, nome) {
  s <- diag$suggestions
  do.call(rbind, lapply(seq_len(nrow(s)), function(k) {
    # "supervised_class" é um modelo que espera um arquivo de amostras SEU
    # (training_samples.gpkg); a versão com amostras é testada na seção 11
    if (s$id[k] == "supervised_class") {
      return(data.frame(diagnostico = nome, analise = s$id[k], aplica_a = s$applies_to[k],
                        rodou = NA, obs = "precisa das suas amostras"))
    }
    ok <- if (is.na(s$code[k])) NA else tryCatch({
      utils::capture.output(roda(s$code[k]))
      TRUE
    }, error = function(e) {
      message("  [erro] ", s$id[k], ": ", conditionMessage(e))
      FALSE
    })
    data.frame(diagnostico = nome, analise = s$id[k], aplica_a = s$applies_to[k],
               rodou = ok, obs = if (is.na(ok)) "sem código de exemplo" else "")
  }))
}

resultado <- rbind(
  roda_tudo(dd, "pasta extdata"),
  roda_tudo(d_amostras, "imagem + amostras"),
  roda_tudo(d_mapa, "mapa de classes"),
  roda_tudo(d_gndvi, "regra própria GNDVI")
)
print(resultado, row.names = FALSE)
cat("\nAnálises que rodaram sem erro:", sum(resultado$rodou, na.rm = TRUE),
    "de", sum(!is.na(resultado$rodou)),
    "(", sum(is.na(resultado$rodou)), "puladas: precisam de amostras suas ou não têm código )\n")
utils::write.csv(resultado, file.path(saida, "execucao_sugestoes.csv"), row.names = FALSE)

if (!interactive()) invisible(dev.off())
cat("\nPronto! Arquivos gerados em:", saida, "\n")
