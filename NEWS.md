# rsguia 0.0.0.9000

* Etapa 1: `diagnosticar()` identifica rasters, vetores e tabelas com
  coordenadas; reconhece bandas e sensor (Sentinel-2, Landsat 4-9, nomes
  genéricos), escala dos valores, MDE, séries temporais e sobreposição
  raster × vetor.
* Etapa 2: `sugerir_analises()`, `regras_rsguia()` e `ver_codigo()`. Regras em
  `inst/regras/regras.csv` (17 análises, incluindo NDRE e NDMI) e modelos de
  código em `inst/exemplos/`, preenchidos com os arquivos e bandas do usuário.
* Dados de exemplo do Vale do Juruá em `inst/extdata/` (script em `data-raw/`).
* Novas regras: métricas de paisagem para mapas de classes e classificação
  supervisionada usando as amostras (pontos/polígonos com classes) do usuário.
* Etapa 3: `print()` com lista curta de sugestões, `summary()` com
  justificativas, cuidados e código (`codigo = TRUE`) e `as.data.frame()` para
  exportar sugestões, itens ou alertas.
* Etapa 4: vignette "Estudo de caso: Vale do Juruá (Acre)" e README.
* Documentação: página geral do pacote (`?rsguia`), página dos dados de exemplo
  (`?dados_jurua`), vignette "Criando suas próprias regras", site pkgdown e
  manual de referência em PDF.
* `regras_rsguia()` e a leitura de tabelas aceitam CSV com ponto e vírgula e
  codificação latin1 (como o Excel salva).
