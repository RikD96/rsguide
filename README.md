# rsguia

**Diagnóstico de dados de sensoriamento remoto e sugestão de análises.**

O rsguia recebe dados de sensoriamento remoto (imagens de satélite, modelos de
elevação, pontos, polígonos ou tabelas com coordenadas), identifica
automaticamente o que eles são e sugere quais análises são possíveis. Cada
sugestão vem com uma justificativa em linguagem simples, os cuidados
necessários e um exemplo de código já preenchido com os seus arquivos e
bandas.

O pacote **não executa** as análises: ele diagnostica e recomenda. É voltado
a ecólogos e estudantes que estão começando no sensoriamento remoto.

## Instalação

```r
# install.packages("remotes")
remotes::install_github("RikD96/rsguia", build_vignettes = TRUE)
```

## Exemplo

```r
library(rsguia)

# Um arquivo, um objeto do R ou uma pasta inteira
pasta <- system.file("extdata", package = "rsguia")
d <- diagnosticar(pasta)
d                      # diagnóstico e lista de análises sugeridas
summary(d)             # justificativas e cuidados de cada análise
ver_codigo(d, "ndvi")  # código pronto para copiar
as.data.frame(d)       # relatório em tabela (para salvar em CSV)
```

O que o `diagnosticar()` identifica:

* tipo de dado: raster, vetor (pontos, linhas, polígonos) ou tabela com
  coordenadas (`lon`/`lat`, `x`/`y`, `decimalLongitude`/`decimalLatitude`...);
* camadas, resolução, sistema de coordenadas, extensão e valores ausentes;
* bandas e provável sensor (Sentinel-2, Landsat 4–9 ou nomes genéricos como
  `red`, `nir`, `swir1`);
* escala dos valores (reflectância 0–1, inteiros ×10.000, Coleção 2 do
  Landsat, deslocamento de +1000 do Sentinel-2...);
* modelos digitais de elevação, mapas de classes e séries temporais;
* se os vetores caem sobre o raster, e se os sistemas de coordenadas batem.

Análises que podem ser sugeridas: NDVI, EVI, SAVI, NDRE, NDMI, NDWI, MNDWI,
NBR, classificação supervisionada e não supervisionada, detecção de mudanças,
análise de tendência, declividade, orientação, bacias e drenagem, extração de
valores em pontos, estatística zonal e métricas de paisagem.

## Regras editáveis

As recomendações vêm de uma tabela (`inst/regras/regras.csv`) em que cada
linha é uma análise, com a condição para sugeri-la. Veja com
`regras_rsguia()` e acrescente regras próprias sem mexer no código:

```r
minhas_regras <- rbind(regras_rsguia(), nova_regra)
diagnosticar(pasta, regras = minhas_regras)
```

## Estudo de caso

A vignette `vignette("estudo-de-caso-jurua", package = "rsguia")` mostra o
diagnóstico de imagens Sentinel-2 do rio Juruá, perto de Cruzeiro do Sul
(AC), do arquivo isolado à pasta com série temporal, MDE e parcelas de campo.
