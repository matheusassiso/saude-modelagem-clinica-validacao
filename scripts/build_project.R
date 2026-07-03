suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(rmarkdown)
  library(scales)
})

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("figures", recursive = TRUE, showWarnings = FALSE)
dir.create("docs", recursive = TRUE, showWarnings = FALSE)
dir.create("docs/figures", recursive = TRUE, showWarnings = FALSE)
invisible(file.create("docs/.nojekyll"))

theme_set(theme_minimal(base_size = 11))
br_percent <- label_percent(decimal.mark = ",", accuracy = 0.1)
br_number <- label_number(big.mark = ".", decimal.mark = ",")

read_project <- function(prefix, label) {
  metrics <- read_csv(sprintf("data/source/%s_metricas_modelos.csv", prefix), show_col_types = FALSE) |>
    mutate(projeto = label, modelo = model)
  cv <- read_csv(sprintf("data/source/%s_metricas_cv.csv", prefix), show_col_types = FALSE) |>
    mutate(projeto = label)
  roc <- read_csv(sprintf("data/source/%s_curva_roc.csv", prefix), show_col_types = FALSE) |>
    mutate(projeto = label)
  calibration <- read_csv(sprintf("data/source/%s_calibracao.csv", prefix), show_col_types = FALSE) |>
    mutate(projeto = label)
  importance <- read_csv(sprintf("data/source/%s_importancia_variaveis.csv", prefix), show_col_types = FALSE) |>
    mutate(projeto = label)
  predictions <- read_csv(sprintf("data/source/%s_predicoes_holdout.csv", prefix), show_col_types = FALSE) |>
    mutate(projeto = label)
  clean <- read_csv(sprintf("data/source/%s_base_limpa.csv", prefix), show_col_types = FALSE)
  list(metrics = metrics, cv = cv, roc = roc, calibration = calibration, importance = importance, predictions = predictions, clean = clean)
}

diabetes <- read_project("diabetes", "Diabetes")
cardiaca <- read_project("cardiaca", "Doença cardíaca")

metricas <- bind_rows(diabetes$metrics, cardiaca$metrics)
cv <- bind_rows(diabetes$cv, cardiaca$cv)
roc <- bind_rows(diabetes$roc, cardiaca$roc)
calibracao <- bind_rows(diabetes$calibration, cardiaca$calibration)
importancia <- bind_rows(diabetes$importance, cardiaca$importance)
predicoes <- bind_rows(diabetes$predictions, cardiaca$predictions)

melhores <- metricas |>
  group_by(projeto) |>
  slice_max(roc_auc, n = 1, with_ties = FALSE) |>
  ungroup()

resumo <- tibble(
  indicador = c(
    "Projetos integrados",
    "Registros na base de diabetes",
    "Registros na base cardíaca",
    "Melhor AUC - diabetes",
    "Melhor AUC - doença cardíaca",
    "Acurácia holdout - diabetes",
    "Acurácia holdout - doença cardíaca",
    "Sensibilidade - diabetes",
    "Sensibilidade - doença cardíaca"
  ),
  valor = c(
    2,
    nrow(diabetes$clean),
    nrow(cardiaca$clean),
    melhores$roc_auc[melhores$projeto == "Diabetes"],
    melhores$roc_auc[melhores$projeto == "Doença cardíaca"],
    melhores$accuracy[melhores$projeto == "Diabetes"],
    melhores$accuracy[melhores$projeto == "Doença cardíaca"],
    melhores$sensitivity[melhores$projeto == "Diabetes"],
    melhores$sensitivity[melhores$projeto == "Doença cardíaca"]
  )
)

write_csv(metricas, "data/processed/metricas_modelos.csv")
write_csv(cv, "data/processed/metricas_validacao_cruzada.csv")
write_csv(roc, "data/processed/curvas_roc.csv")
write_csv(calibracao, "data/processed/calibracao_modelos.csv")
write_csv(importancia, "data/processed/importancia_variaveis.csv")
write_csv(predicoes, "data/processed/predicoes_holdout.csv")
write_csv(resumo, "data/processed/resumo_indicadores.csv")

p_metricas <- metricas |>
  select(projeto, modelo, accuracy, sensitivity, specificity, precision, f1, roc_auc) |>
  tidyr::pivot_longer(accuracy:roc_auc, names_to = "metrica", values_to = "valor") |>
  ggplot(aes(metrica, valor, fill = modelo)) +
  geom_col(position = "dodge") +
  facet_wrap(~projeto) +
  scale_y_continuous(labels = br_percent, limits = c(0, 1)) +
  labs(title = "Métricas de validação no holdout", x = NULL, y = NULL, fill = "Modelo") +
  theme(plot.title = element_text(face = "bold"), axis.text.x = element_text(angle = 35, hjust = 1))
ggsave("figures/01_metricas_holdout.png", p_metricas, width = 10, height = 6, dpi = 160)

p_roc <- roc |>
  ggplot(aes(fpr, sensitivity, color = projeto)) +
  geom_abline(linetype = "dashed", color = "gray55") +
  geom_line(linewidth = 1) +
  coord_equal() +
  scale_x_continuous(labels = br_percent) +
  scale_y_continuous(labels = br_percent) +
  labs(title = "Curvas ROC dos modelos logísticos", x = "1 - especificidade", y = "Sensibilidade", color = "Projeto") +
  theme(plot.title = element_text(face = "bold"))
ggsave("figures/02_curvas_roc.png", p_roc, width = 8, height = 6, dpi = 160)

p_cal <- calibracao |>
  ggplot(aes(mean_probability, observed_rate, color = projeto)) +
  geom_abline(linetype = "dashed", color = "gray55") +
  geom_point(size = 2.5) +
  geom_line(linewidth = 0.8) +
  scale_x_continuous(labels = br_percent, limits = c(0, 1)) +
  scale_y_continuous(labels = br_percent, limits = c(0, 1)) +
  labs(title = "Calibração: probabilidade prevista vs. taxa observada", x = "Probabilidade média prevista", y = "Taxa observada", color = "Projeto") +
  theme(plot.title = element_text(face = "bold"))
ggsave("figures/03_calibracao.png", p_cal, width = 8, height = 6, dpi = 160)

p_imp <- importancia |>
  group_by(projeto) |>
  slice_max(importance, n = 8) |>
  ungroup() |>
  mutate(variable = reorder(variable, importance)) |>
  ggplot(aes(importance, variable, fill = direction)) +
  geom_col() +
  facet_wrap(~projeto, scales = "free_y") +
  labs(title = "Variáveis mais importantes nos modelos logísticos", x = "Importância absoluta", y = NULL, fill = "Direção") +
  theme(plot.title = element_text(face = "bold"))
ggsave("figures/04_importancia_variaveis.png", p_imp, width = 10, height = 6, dpi = 160)

outcome_diabetes <- diabetes$clean |>
  count(outcome_label, name = "n") |>
  mutate(projeto = "Diabetes", classe = outcome_label)
outcome_cardiaca <- cardiaca$clean |>
  count(target_label, name = "n") |>
  mutate(projeto = "Doença cardíaca", classe = target_label)
p_outcome <- bind_rows(
  select(outcome_diabetes, projeto, classe, n),
  select(outcome_cardiaca, projeto, classe, n)
) |>
  ggplot(aes(classe, n, fill = classe)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~projeto, scales = "free_x") +
  scale_y_continuous(labels = br_number) +
  labs(title = "Distribuição dos desfechos nas bases limpas", x = NULL, y = "Registros") +
  theme(plot.title = element_text(face = "bold"))
ggsave("figures/05_distribuicao_desfechos.png", p_outcome, width = 9, height = 6, dpi = 160)

cm <- metricas |>
  filter(model == "logistic") |>
  select(projeto, tp, fp, tn, fn) |>
  tidyr::pivot_longer(tp:fn, names_to = "celula", values_to = "n")
p_cm <- cm |>
  ggplot(aes(celula, n, fill = projeto)) +
  geom_col(position = "dodge") +
  scale_y_continuous(labels = br_number) +
  labs(title = "Matriz de confusão resumida do modelo logístico", x = NULL, y = "Registros", fill = "Projeto") +
  theme(plot.title = element_text(face = "bold"))
ggsave("figures/06_matriz_confusao.png", p_cm, width = 9, height = 6, dpi = 160)

fmt_pct <- function(x) sprintf("%.1f%%", 100 * x)
cards <- melhores |>
  transmute(
    projeto,
    html = sprintf(
      "<article class='card'><h2>%s</h2><p class='model'>Melhor modelo: %s</p><dl><dt>AUC</dt><dd>%s</dd><dt>Acurácia</dt><dd>%s</dd><dt>Sensibilidade</dt><dd>%s</dd><dt>Especificidade</dt><dd>%s</dd></dl></article>",
      projeto, modelo, fmt_pct(roc_auc), fmt_pct(accuracy), fmt_pct(sensitivity), fmt_pct(specificity)
    )
  ) |>
  pull(html) |>
  paste(collapse = "\n")

dashboard <- sprintf(
'<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Modelagem clínica e validação</title>
<style>
body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#f7f8fa;color:#1f2933}
header{padding:32px 5vw 18px;background:#ffffff;border-bottom:1px solid #d9dee7}
h1{margin:0 0 8px;font-size:clamp(28px,4vw,44px)}
p{line-height:1.55}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px;padding:24px 5vw}
.card{background:#fff;border:1px solid #d9dee7;border-radius:8px;padding:18px}
.card h2{margin:0 0 8px;font-size:22px}
.model{color:#52606d}
dl{display:grid;grid-template-columns:1fr auto;gap:8px;margin:12px 0 0}
dt{color:#52606d} dd{margin:0;font-weight:700}
.figures{padding:0 5vw 36px;display:grid;gap:24px}
figure{margin:0;background:#fff;border:1px solid #d9dee7;border-radius:8px;padding:12px}
img{max-width:100%%;height:auto;display:block}
figcaption{font-weight:700;margin:8px 0 0}
footer{padding:20px 5vw;color:#52606d}
.note{padding:0 5vw 12px}.note .card{max-width:980px}.links{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}.links a{border:1px solid #d9dee7;border-radius:8px;padding:8px 10px;background:#fff;color:#245b87;text-decoration:none}
</style>
</head>
<body>
<header>
<h1>Modelagem clínica e validação estatística</h1>
<p>Dashboard executivo com comparação entre modelos de diabetes e doença cardíaca, destacando validação holdout, ROC, calibração, interpretabilidade e matriz de confusão.</p>
<div class="links"><a href="../modelagem_clinica_validacao.pdf">PDF acadêmico</a><a href="../modelagem_clinica_validacao.Rmd">Rmd</a><a href="relatorio.html">Relatório HTML</a></div>
</header>
<section class="grid">%s</section>
<section class="note"><article class="card"><h2>Análise descritiva e exploratória</h2><p>O dashboard consolida duas bases clínicas em um fluxo profissional de ciência de dados: preparação dos registros, comparação de desempenho, avaliação de discriminação, calibração, interpretação por variáveis e leitura dos erros no holdout. Este projeto não possui componente geoespacial real; por isso, a entrega mantém o foco em validação estatística e explicabilidade clínica.</p></article></section>
<section class="figures">
<figure><img src="figures/01_metricas_holdout.png" alt="Métricas holdout"><figcaption>Métricas de validação</figcaption></figure>
<figure><img src="figures/02_curvas_roc.png" alt="Curvas ROC"><figcaption>Curvas ROC</figcaption></figure>
<figure><img src="figures/03_calibracao.png" alt="Calibração"><figcaption>Calibração</figcaption></figure>
<figure><img src="figures/04_importancia_variaveis.png" alt="Importância de variáveis"><figcaption>Importância de variáveis</figcaption></figure>
<figure><img src="figures/05_distribuicao_desfechos.png" alt="Distribuição dos desfechos"><figcaption>Distribuição dos desfechos</figcaption></figure>
<figure><img src="figures/06_matriz_confusao.png" alt="Matriz de confusão"><figcaption>Matriz de confusão</figcaption></figure>
</section>
<footer>Artefato gerado por scripts/build_project.R</footer>
</body>
</html>', cards)

writeLines(dashboard, "docs/modelagem_clinica_dashboard.html", useBytes = TRUE)
invisible(file.copy("docs/modelagem_clinica_dashboard.html", "docs/index.html", overwrite = TRUE))
invisible(file.copy(list.files("figures", full.names = TRUE), "docs/figures", overwrite = TRUE))

render("modelagem_clinica_validacao.Rmd", output_format = "html_document", output_file = "relatorio.html", output_dir = "docs", quiet = TRUE)
render("modelagem_clinica_validacao.Rmd", output_format = "pdf_document", output_file = "modelagem_clinica_validacao.pdf", quiet = TRUE)

message("Projeto reconstruído: dashboard, PDF, HTML, dados e figuras atualizados.")
