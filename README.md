# Modelagem Clinica e Validacao Estatistica

## Motivacao

Modelos clinicos so sao uteis como portfolio quando mostram validacao, interpretabilidade e limites de uso, nao apenas acuracia.

## Objetivo da pesquisa

Demonstrar pipelines de classificacao supervisionada para diabetes e doenca cardiaca com metricas, calibracao e importancia de variaveis.

## Resultados

O repositorio apresenta modelos validados com curva ROC, matriz de confusao, calibracao, importancia de variaveis, previsoes holdout e relatorios tecnicos.

## Dashboard executivo

Abra a apresentacao em [docs/index.html](docs/index.html). Ela resume a pesquisa, lista os entregaveis e aponta para os dashboards originais de cada estudo.

## Projetos incluidos

| Estudo | Dashboard | Relatorios | Mapa |
|---|---|---|---|
| 13 - classificacao-diabetes-validacao-estatistica | [Dashboard](projects/13 - classificacao-diabetes-validacao-estatistica/docs/index.html) | [13-kaggle-diabetes-classification.html](projects/13 - classificacao-diabetes-validacao-estatistica/reports/13-kaggle-diabetes-classification.html)<br>[13-kaggle-diabetes-classification.pdf](projects/13 - classificacao-diabetes-validacao-estatistica/reports/13-kaggle-diabetes-classification.pdf) | Nao |
| 14 - classificacao-doenca-cardiaca-aprendizado-maquina | [Dashboard](projects/14 - classificacao-doenca-cardiaca-aprendizado-maquina/docs/index.html) | [14-kaggle-heart-disease-classification.html](projects/14 - classificacao-doenca-cardiaca-aprendizado-maquina/reports/14-kaggle-heart-disease-classification.html)<br>[14-kaggle-heart-disease-classification.pdf](projects/14 - classificacao-doenca-cardiaca-aprendizado-maquina/reports/14-kaggle-heart-disease-classification.pdf) | Nao |

## Estrutura

- `docs/index.html`: apresentacao executiva do repositorio.
- `projects/`: estudos originais preservados para auditoria.
- `projects/*/src/R`: scripts analiticos.
- `projects/*/reports`: relatorios tecnicos e figuras.
- `projects/*/data/processed`: bases finais usadas nos dashboards.

## Reprodutibilidade

Os dados brutos pesados, caches publicos e bases processadas record-level acima de 50 MB nao entram no Git para manter o repositorio publicavel. Quando necessario, consulte `data/raw/README.md`, scripts em `src/R` e instrucoes de download dentro de cada estudo.

## Limites

As analises sao exploratorias e tecnicas. Mapas, rankings e modelos apoiam triagem e hipotese; nao substituem validacao institucional, auditoria documental ou decisao clinica.
