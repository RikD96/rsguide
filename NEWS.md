# rsguia 0.1.0

Primeira versão.

* `diagnosticar()` identifica rasters, vetores e tabelas com coordenadas;
  reconhece bandas e sensor (Sentinel-2, Landsat 4-9, nomes genéricos), escala
  dos valores (incluindo o deslocamento de +1000 do Sentinel-2), MDE, mapas de
  classes, séries temporais e sobreposição raster × vetor.
* `sugerir_analises()` compara o diagnóstico com uma tabela editável de 19
  regras (`regras_rsguia()`) e sugere análises com justificativa, cuidados,
  pacotes e código de exemplo já preenchido (`ver_codigo()`).
* `print()`, `summary()` e `as.data.frame()` para ler e exportar o relatório.
* Dados de exemplo do rio Juruá (AC) e duas vignettes: estudo de caso e
  criação de regras próprias.
