# Classificação de diabetes com validação estatística

**Tema:** Saúde
**Pasta:** `13 - kaggle-diabetes-classification`
**Repositório sugerido:** `13-kaggle-diabetes-classification`
**Autor:** Matheus Assis de Oliveira

## Visão Geral

O problema central é organizar registros públicos de saúde em evidências municipais interpretáveis, permitindo avaliar distribuição territorial, intensidade de serviços, riscos epidemiológicos e desigualdades de acesso ou resultado.

Este projeto foi preparado para funcionar como um repositório independente dentro do super-repositório. A pasta reúne dados, scripts, relatório em PDF, relatório HTML, dashboard interativo e instruções de publicação.

## Problema de Análise

A pergunta prática é: como transformar dados públicos em evidências territoriais, estatísticas e visuais que possam ser auditadas, reproduzidas e interpretadas por município ou unidade de análise? O projeto organiza a resposta em uma estrutura de portfólio, com foco em clareza, reprodutibilidade e leitura espacial sempre que houver dados geográficos.

## Dados e Escopo

- Arquivos de dados no projeto: **14**.
- Arquivos CSV: **11**.
- Scripts analíticos: **1**.
- Figuras e imagens: **4**.
- Relatórios PDF/HTML: **1 PDF** e **2 HTML**.

Os dados brutos ficam em `data/raw/` e as bases tratadas ficam em `data/processed/`. Essa separação permite revisar a origem, repetir o tratamento e comparar os resultados finais com as bases intermediárias.

## Métodos

O método estrutura dados públicos de saúde em bases limpas, calcula indicadores municipais, compara padrões temporais e territoriais e documenta limitações epidemiológicas. Quando há geometria municipal, o dashboard utiliza mapa interativo para apoiar leitura espacial das estatísticas.

A abordagem combina:

- organização de dados em formato tabular;
- limpeza e padronização de variáveis;
- construção de indicadores descritivos;
- visualização estatística e, quando aplicável, cartográfica;
- documentação de limites, pressupostos e cuidados de interpretação.

## Análise Espacial e Mapas

Este projeto não possui camada GeoJSON própria nesta versão; a leitura espacial fica concentrada nas tabelas, gráficos e, quando aplicável, nos indicadores territoriais do relatório.

Nos projetos com mapa, o dashboard permite observar concentração, dispersão, agrupamentos territoriais e possíveis desigualdades espaciais. A leitura espacial deve ser interpretada como análise exploratória: ela aponta padrões e hipóteses, mas não prova causalidade sozinha.

## Resultados e Entregáveis

Os resultados entregam indicadores organizados, visualizações, relatório técnico e dashboard para leitura municipal. O foco é apoiar avaliação exploratória, monitoramento e formulação de hipóteses, sem substituir validação institucional ou decisão clínica.

| Entregável | Link |
|---|---|
| Dashboard interativo | [abrir dashboard](<docs/index.html>) |
| Relatório técnico em PDF | [abrir PDF](<reports/13-kaggle-diabetes-classification.pdf>) |
| Relatório HTML renderizado | [abrir HTML](<reports/13-kaggle-diabetes-classification.html>) |
| Instruções de commit/publicação | [abrir instruções](<COMMIT_INSTRUCTIONS.txt>) |
| README original em inglês | [abrir referência](<README_EN.md>) |

## Como Avaliar Este Projeto no Super-Repositório

1. Leia este README para entender problema, método, dados e entregáveis.
2. Abra o dashboard em `docs/index.html` para navegar por dados, gráficos e mapas.
3. Consulte o PDF para uma leitura em formato de artigo técnico.
4. Verifique `src/R/` para auditar o código analítico.
5. Use `COMMIT_INSTRUCTIONS.txt` se quiser transformar esta pasta em um repositório individual.

## Limitações

Os resultados devem ser lidos como análise técnica e exploratória. Bases públicas podem ter atraso, revisão, ausência de variáveis explicativas e diferenças de cobertura entre municípios. Em projetos de saúde, os indicadores não substituem validação institucional nem decisão clínica. Em projetos agropecuários, os padrões não substituem avaliação agronômica local.
