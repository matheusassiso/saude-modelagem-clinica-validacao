library(dplyr)
library(ggplot2)
library(readr)
library(rpart)
library(tibble)
library(tidyr)

s13_seed <- 13013
s13_project_dir <- normalizePath(file.path(getwd()), winslash = "/", mustWork = FALSE)
s13_raw_url <- "https://raw.githubusercontent.com/npradaschnor/Pima-Indians-Diabetes-Dataset/master/diabetes.csv"
s13_kaggle_url <- "https://www.kaggle.com/datasets/uciml/pima-indians-diabetes-database"
s13_predictors <- c("Pregnancies", "Glucose", "BloodPressure", "SkinThickness", "Insulin", "BMI", "DiabetesPedigreeFunction", "Age")
s13_zero_missing <- c("Glucose", "BloodPressure", "SkinThickness", "Insulin", "BMI")

s13_dir <- function(...) file.path(s13_project_dir, ...)

ensure_s13_dirs <- function() {
  dirs <- c(s13_dir("data", "raw"), s13_dir("data", "processed"), s13_dir("reports", "figures"))
  invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
}

download_s13_data <- function(force = FALSE) {
  ensure_s13_dirs()
  raw_path <- s13_dir("data", "raw", "diabetes.csv")
  metadata_path <- s13_dir("data", "raw", "s13_source_metadata.csv")

  if (!file.exists(raw_path) || force) {
    download.file(s13_raw_url, raw_path, mode = "wb", quiet = TRUE)
  }

  write_csv(
    tibble(
      file = "diabetes.csv",
      canonical_source = s13_kaggle_url,
      local_build_source = s13_raw_url,
      access_note = "Kaggle is the canonical source; a public CSV mirror is used when Kaggle CLI is unavailable.",
      retrieved_at = as.character(Sys.time())
    ),
    metadata_path
  )

  raw_path
}

read_s13_data <- function(force_download = FALSE) {
  raw_path <- download_s13_data(force = force_download)
  data <- read_csv(raw_path, show_col_types = FALSE)
  required <- c(s13_predictors, "Outcome")
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) stop("Missing required columns: ", paste(missing_cols, collapse = ", "))

  data |>
    transmute(
      across(all_of(s13_predictors), as.numeric),
      Outcome = as.integer(Outcome),
      outcome_label = factor(if_else(Outcome == 1, "Diabetes", "No diabetes"), levels = c("No diabetes", "Diabetes"))
    )
}

clean_s13_data <- function(data) {
  data |>
    mutate(across(all_of(s13_zero_missing), ~if_else(.x == 0, NA_real_, .x)))
}

stratified_split_s13 <- function(data, prop = 0.80, seed = s13_seed) {
  set.seed(seed)
  split_data <- data |>
    group_by(outcome_label) |>
    mutate(split_rank = sample(row_number()), split_set = if_else(split_rank <= floor(n() * prop), "train", "test")) |>
    ungroup() |>
    select(-split_rank)

  list(
    train = split_data |> filter(split_set == "train") |> select(-split_set),
    test = split_data |> filter(split_set == "test") |> select(-split_set),
    metadata = split_data |> count(split_set, outcome_label, name = "records")
  )
}

learn_preprocess <- function(train) {
  medians <- sapply(train[s13_predictors], median, na.rm = TRUE)
  imputed <- train
  for (feature in s13_predictors) imputed[[feature]][is.na(imputed[[feature]])] <- medians[[feature]]
  centers <- sapply(imputed[s13_predictors], mean, na.rm = TRUE)
  scales <- sapply(imputed[s13_predictors], sd, na.rm = TRUE)
  scales[scales == 0 | is.na(scales)] <- 1
  list(medians = medians, centers = centers, scales = scales)
}

apply_preprocess <- function(data, params, standardize = TRUE) {
  out <- data
  for (feature in s13_predictors) {
    out[[feature]][is.na(out[[feature]])] <- params$medians[[feature]]
    if (standardize) out[[feature]] <- (out[[feature]] - params$centers[[feature]]) / params$scales[[feature]]
  }
  out
}

roc_auc_manual <- function(truth, score) {
  truth <- as.integer(truth)
  pos <- sum(truth == 1)
  neg <- sum(truth == 0)
  if (pos == 0 || neg == 0) return(NA_real_)
  ranks <- rank(score, ties.method = "average")
  (sum(ranks[truth == 1]) - pos * (pos + 1) / 2) / (pos * neg)
}

roc_curve_points <- function(truth, score) {
  thresholds <- sort(unique(c(Inf, score, -Inf)), decreasing = TRUE)
  bind_rows(lapply(thresholds, function(th) {
    pred <- if_else(score >= th, 1L, 0L)
    tp <- sum(truth == 1 & pred == 1)
    fp <- sum(truth == 0 & pred == 1)
    tn <- sum(truth == 0 & pred == 0)
    fn <- sum(truth == 1 & pred == 0)
    tibble(
      threshold = th,
      sensitivity = ifelse(tp + fn == 0, NA_real_, tp / (tp + fn)),
      specificity = ifelse(tn + fp == 0, NA_real_, tn / (tn + fp)),
      fpr = 1 - specificity
    )
  }))
}

classification_metrics_s13 <- function(truth, probability, threshold = 0.5) {
  pred <- if_else(probability >= threshold, 1L, 0L)
  tp <- sum(truth == 1 & pred == 1)
  fp <- sum(truth == 0 & pred == 1)
  tn <- sum(truth == 0 & pred == 0)
  fn <- sum(truth == 1 & pred == 0)
  sensitivity <- ifelse(tp + fn == 0, NA_real_, tp / (tp + fn))
  specificity <- ifelse(tn + fp == 0, NA_real_, tn / (tn + fp))
  precision <- ifelse(tp + fp == 0, NA_real_, tp / (tp + fp))
  f1 <- ifelse(is.na(precision + sensitivity) || precision + sensitivity == 0, NA_real_, 2 * precision * sensitivity / (precision + sensitivity))

  tibble(
    accuracy = (tp + tn) / (tp + fp + tn + fn),
    sensitivity = sensitivity,
    specificity = specificity,
    precision = precision,
    f1 = f1,
    roc_auc = roc_auc_manual(truth, probability),
    threshold = threshold,
    tp = tp,
    fp = fp,
    tn = tn,
    fn = fn
  )
}

fit_s13_models <- function(train_scaled, train_raw) {
  logistic <- glm(Outcome ~ ., data = train_scaled |> select(all_of(s13_predictors), Outcome), family = binomial())
  tree <- rpart(
    outcome_label ~ .,
    data = train_raw |> select(all_of(s13_predictors), outcome_label),
    method = "class",
    control = rpart.control(cp = 0.01, minsplit = 20, xval = 0)
  )
  list(logistic = logistic, tree = tree)
}

predict_s13_model <- function(model, data_scaled, data_raw, model_name) {
  if (model_name == "logistic") {
    as.numeric(predict(model, newdata = data_scaled, type = "response"))
  } else {
    probs <- predict(model, newdata = data_raw, type = "prob")
    as.numeric(probs[, "Diabetes"])
  }
}

evaluate_s13_split <- function(train, test) {
  params <- learn_preprocess(train)
  train_scaled <- apply_preprocess(train, params, standardize = TRUE)
  test_scaled <- apply_preprocess(test, params, standardize = TRUE)
  train_raw <- apply_preprocess(train, params, standardize = FALSE)
  test_raw <- apply_preprocess(test, params, standardize = FALSE)
  models <- fit_s13_models(train_scaled, train_raw)

  bind_rows(lapply(names(models), function(model_name) {
    probability <- predict_s13_model(models[[model_name]], test_scaled, test_raw, model_name)
    classification_metrics_s13(test$Outcome, probability) |> mutate(model = model_name, .before = 1)
  }))
}

cross_validate_s13 <- function(train, v = 5, seed = s13_seed + 1) {
  set.seed(seed)
  folded <- train |>
    group_by(outcome_label) |>
    mutate(fold_id = sample(rep(seq_len(v), length.out = n()))) |>
    ungroup()

  bind_rows(lapply(seq_len(v), function(fold) {
    fold_train <- folded |> filter(fold_id != fold) |> select(-fold_id)
    fold_test <- folded |> filter(fold_id == fold) |> select(-fold_id)
    evaluate_s13_split(fold_train, fold_test) |> mutate(fold = fold, .before = 1)
  }))
}

calibration_bins <- function(truth, probability, bins = 5) {
  tibble(truth = truth, probability = probability) |>
    mutate(bin = ntile(probability, bins)) |>
    group_by(bin) |>
    summarise(
      records = n(),
      mean_probability = mean(probability),
      observed_rate = mean(truth),
      .groups = "drop"
    )
}

make_s13_figures <- function(clean_data, predictions, roc_points, importance, calibration) {
  ensure_s13_dirs()
  fig_dir <- s13_dir("reports", "figures")

  p_outcome <- clean_data |>
    count(outcome_label) |>
    ggplot(aes(x = outcome_label, y = n, fill = outcome_label)) +
    geom_col(width = 0.65, show.legend = FALSE) +
    scale_fill_manual(values = c("No diabetes" = "#3A7CA5", "Diabetes" = "#D95F02")) +
    labs(x = NULL, y = "Records", title = "Outcome distribution")
  ggsave(file.path(fig_dir, "s13_outcome_distribution.png"), p_outcome, width = 6.5, height = 4.2, dpi = 300)

  p_roc <- roc_points |>
    ggplot(aes(x = fpr, y = sensitivity)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
    geom_line(color = "#08519C", linewidth = 0.8) +
    coord_equal() +
    labs(x = "False positive rate", y = "Sensitivity", title = "Selected-model ROC curve")
  ggsave(file.path(fig_dir, "s13_roc_curve.png"), p_roc, width = 5.5, height = 5.2, dpi = 300)

  p_importance <- importance |>
    ggplot(aes(x = reorder(variable, importance), y = importance)) +
    geom_col(fill = "#4C956C", width = 0.70) +
    coord_flip() +
    labs(x = NULL, y = "Absolute standardized coefficient", title = "Logistic model variable importance")
  ggsave(file.path(fig_dir, "s13_variable_importance.png"), p_importance, width = 7.2, height = 4.6, dpi = 300)

  p_cal <- calibration |>
    ggplot(aes(x = mean_probability, y = observed_rate)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
    geom_point(size = 2.4, color = "#D95F02") +
    geom_line(color = "#D95F02") +
    coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
    labs(x = "Mean predicted probability", y = "Observed diabetes rate", title = "Calibration bins")
  ggsave(file.path(fig_dir, "s13_calibration.png"), p_cal, width = 5.5, height = 5.2, dpi = 300)
}

prepare_s13_outputs <- function(force = FALSE) {
  ensure_s13_dirs()
  clean_data <- read_s13_data(force_download = force) |> clean_s13_data()
  split <- stratified_split_s13(clean_data)
  params <- learn_preprocess(split$train)
  train_scaled <- apply_preprocess(split$train, params, standardize = TRUE)
  test_scaled <- apply_preprocess(split$test, params, standardize = TRUE)
  train_raw <- apply_preprocess(split$train, params, standardize = FALSE)
  test_raw <- apply_preprocess(split$test, params, standardize = FALSE)
  models <- fit_s13_models(train_scaled, train_raw)

  metrics <- bind_rows(lapply(names(models), function(model_name) {
    probability <- predict_s13_model(models[[model_name]], test_scaled, test_raw, model_name)
    classification_metrics_s13(split$test$Outcome, probability) |> mutate(model = model_name, .before = 1)
  })) |> arrange(desc(roc_auc))

  selected_model <- metrics |> slice_head(n = 1) |> pull(model)
  selected_probability <- predict_s13_model(models[[selected_model]], test_scaled, test_raw, selected_model)
  predictions <- split$test |>
    mutate(
      model = selected_model,
      predicted_probability = selected_probability,
      predicted_outcome = if_else(predicted_probability >= 0.5, 1L, 0L),
      predicted_label = factor(if_else(predicted_outcome == 1, "Diabetes", "No diabetes"), levels = c("No diabetes", "Diabetes"))
    )

  confusion <- predictions |>
    count(outcome_label, predicted_label, name = "records") |>
    complete(outcome_label, predicted_label, fill = list(records = 0))

  cv_metrics <- cross_validate_s13(split$train)
  roc_points <- roc_curve_points(predictions$Outcome, predictions$predicted_probability)
  calibration <- calibration_bins(predictions$Outcome, predictions$predicted_probability)

  logistic_coef <- coef(models$logistic)
  importance <- tibble(
    variable = names(logistic_coef)[-1],
    coefficient = as.numeric(logistic_coef[-1]),
    importance = abs(coefficient),
    direction = if_else(coefficient >= 0, "Higher probability", "Lower probability")
  ) |> arrange(desc(importance))

  write_csv(clean_data, s13_dir("data", "processed", "s13_clean_diabetes.csv"))
  write_csv(split$metadata, s13_dir("data", "processed", "s13_split_metadata.csv"))
  write_csv(metrics, s13_dir("data", "processed", "s13_model_metrics.csv"))
  write_csv(confusion, s13_dir("data", "processed", "s13_confusion_matrix.csv"))
  write_csv(cv_metrics, s13_dir("data", "processed", "s13_cv_metrics.csv"))
  write_csv(predictions, s13_dir("data", "processed", "s13_holdout_predictions.csv"))
  write_csv(roc_points, s13_dir("data", "processed", "s13_roc_curve.csv"))
  write_csv(calibration, s13_dir("data", "processed", "s13_calibration_bins.csv"))
  write_csv(importance, s13_dir("data", "processed", "s13_variable_importance.csv"))

  make_s13_figures(clean_data, predictions, roc_points, importance, calibration)

  invisible(list(metrics = metrics, selected_model = selected_model, predictions = predictions, cv_metrics = cv_metrics))
}
