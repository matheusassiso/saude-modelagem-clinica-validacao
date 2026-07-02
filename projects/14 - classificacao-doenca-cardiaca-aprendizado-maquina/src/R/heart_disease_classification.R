library(dplyr)
library(ggplot2)
library(readr)
library(rpart)
library(tibble)
library(tidyr)

s14_seed <- 14014
s14_project_dir <- normalizePath(file.path(getwd()), winslash = "/", mustWork = FALSE)
s14_raw_url <- "https://raw.githubusercontent.com/kb22/Heart-Disease-Prediction/master/dataset.csv"
s14_kaggle_url <- "https://www.kaggle.com/datasets/johnsmith88/heart-disease-dataset"
s14_predictors <- c("age", "sex", "cp", "trestbps", "chol", "fbs", "restecg", "thalach", "exang", "oldpeak", "slope", "ca", "thal")

s14_dir <- function(...) file.path(s14_project_dir, ...)

ensure_s14_dirs <- function() {
  dirs <- c(s14_dir("data", "raw"), s14_dir("data", "processed"), s14_dir("reports", "figures"))
  invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
}

download_s14_data <- function(force = FALSE) {
  ensure_s14_dirs()
  raw_path <- s14_dir("data", "raw", "heart.csv")
  metadata_path <- s14_dir("data", "raw", "s14_source_metadata.csv")

  if (!file.exists(raw_path) || force) {
    download.file(s14_raw_url, raw_path, mode = "wb", quiet = TRUE)
  }

  write_csv(
    tibble(
      file = "heart.csv",
      canonical_source = s14_kaggle_url,
      local_build_source = s14_raw_url,
      access_note = "Kaggle is the canonical source; a public CSV mirror is used when Kaggle CLI is unavailable.",
      retrieved_at = as.character(Sys.time())
    ),
    metadata_path
  )
  raw_path
}

read_s14_data <- function(force_download = FALSE) {
  raw_path <- download_s14_data(force = force_download)
  data <- read_csv(raw_path, show_col_types = FALSE)
  required <- c(s14_predictors, "target")
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) stop("Missing required columns: ", paste(missing_cols, collapse = ", "))

  data |>
    transmute(
      across(all_of(s14_predictors), as.numeric),
      target = as.integer(target),
      target_label = factor(if_else(target == 1, "Heart disease", "No heart disease"), levels = c("No heart disease", "Heart disease"))
    )
}

stratified_split_s14 <- function(data, prop = 0.80, seed = s14_seed) {
  set.seed(seed)
  split_data <- data |>
    group_by(target_label) |>
    mutate(split_rank = sample(row_number()), split_set = if_else(split_rank <= floor(n() * prop), "train", "test")) |>
    ungroup() |>
    select(-split_rank)

  list(
    train = split_data |> filter(split_set == "train") |> select(-split_set),
    test = split_data |> filter(split_set == "test") |> select(-split_set),
    metadata = split_data |> count(split_set, target_label, name = "records")
  )
}

learn_standardization <- function(train) {
  centers <- sapply(train[s14_predictors], mean, na.rm = TRUE)
  scales <- sapply(train[s14_predictors], sd, na.rm = TRUE)
  scales[scales == 0 | is.na(scales)] <- 1
  list(centers = centers, scales = scales)
}

apply_standardization <- function(data, params) {
  out <- data
  for (feature in s14_predictors) {
    out[[feature]] <- (out[[feature]] - params$centers[[feature]]) / params$scales[[feature]]
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

classification_metrics_s14 <- function(truth, probability, threshold = 0.5) {
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

fit_s14_models <- function(train_scaled, train_raw) {
  logistic <- glm(target ~ ., data = train_scaled |> select(all_of(s14_predictors), target), family = binomial())
  tree <- rpart(
    target_label ~ .,
    data = train_raw |> select(all_of(s14_predictors), target_label),
    method = "class",
    control = rpart.control(cp = 0.01, minsplit = 12, xval = 0)
  )
  list(logistic = logistic, tree = tree)
}

predict_s14_model <- function(model, data_scaled, data_raw, model_name) {
  if (model_name == "logistic") {
    as.numeric(predict(model, newdata = data_scaled, type = "response"))
  } else {
    probs <- predict(model, newdata = data_raw, type = "prob")
    as.numeric(probs[, "Heart disease"])
  }
}

evaluate_s14_split <- function(train, test) {
  params <- learn_standardization(train)
  train_scaled <- apply_standardization(train, params)
  test_scaled <- apply_standardization(test, params)
  models <- fit_s14_models(train_scaled, train)

  bind_rows(lapply(names(models), function(model_name) {
    probability <- predict_s14_model(models[[model_name]], test_scaled, test, model_name)
    classification_metrics_s14(test$target, probability) |> mutate(model = model_name, .before = 1)
  }))
}

cross_validate_s14 <- function(train, v = 5, seed = s14_seed + 1) {
  set.seed(seed)
  folded <- train |>
    group_by(target_label) |>
    mutate(fold_id = sample(rep(seq_len(v), length.out = n()))) |>
    ungroup()

  bind_rows(lapply(seq_len(v), function(fold) {
    fold_train <- folded |> filter(fold_id != fold) |> select(-fold_id)
    fold_test <- folded |> filter(fold_id == fold) |> select(-fold_id)
    evaluate_s14_split(fold_train, fold_test) |> mutate(fold = fold, .before = 1)
  }))
}

calibration_bins <- function(truth, probability, bins = 5) {
  tibble(truth = truth, probability = probability) |>
    mutate(bin = ntile(probability, bins)) |>
    group_by(bin) |>
    summarise(records = n(), mean_probability = mean(probability), observed_rate = mean(truth), .groups = "drop")
}

make_s14_figures <- function(clean_data, roc_points, importance, calibration) {
  ensure_s14_dirs()
  fig_dir <- s14_dir("reports", "figures")

  p_outcome <- clean_data |>
    count(target_label) |>
    ggplot(aes(x = target_label, y = n, fill = target_label)) +
    geom_col(width = 0.65, show.legend = FALSE) +
    scale_fill_manual(values = c("No heart disease" = "#3A7CA5", "Heart disease" = "#B2182B")) +
    labs(x = NULL, y = "Records", title = "Outcome distribution")
  ggsave(file.path(fig_dir, "s14_outcome_distribution.png"), p_outcome, width = 6.5, height = 4.2, dpi = 300)

  p_roc <- roc_points |>
    ggplot(aes(x = fpr, y = sensitivity)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
    geom_line(color = "#08519C", linewidth = 0.8) +
    coord_equal() +
    labs(x = "False positive rate", y = "Sensitivity", title = "Selected-model ROC curve")
  ggsave(file.path(fig_dir, "s14_roc_curve.png"), p_roc, width = 5.5, height = 5.2, dpi = 300)

  p_importance <- importance |>
    ggplot(aes(x = reorder(variable, importance), y = importance)) +
    geom_col(fill = "#4C956C", width = 0.70) +
    coord_flip() +
    labs(x = NULL, y = "Absolute standardized coefficient", title = "Logistic model variable importance")
  ggsave(file.path(fig_dir, "s14_variable_importance.png"), p_importance, width = 7.2, height = 4.6, dpi = 300)

  p_cal <- calibration |>
    ggplot(aes(x = mean_probability, y = observed_rate)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
    geom_point(size = 2.4, color = "#B2182B") +
    geom_line(color = "#B2182B") +
    coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
    labs(x = "Mean predicted probability", y = "Observed heart disease rate", title = "Calibration bins")
  ggsave(file.path(fig_dir, "s14_calibration.png"), p_cal, width = 5.5, height = 5.2, dpi = 300)
}

prepare_s14_outputs <- function(force = FALSE) {
  ensure_s14_dirs()
  clean_data <- read_s14_data(force_download = force)
  split <- stratified_split_s14(clean_data)
  params <- learn_standardization(split$train)
  train_scaled <- apply_standardization(split$train, params)
  test_scaled <- apply_standardization(split$test, params)
  models <- fit_s14_models(train_scaled, split$train)

  metrics <- bind_rows(lapply(names(models), function(model_name) {
    probability <- predict_s14_model(models[[model_name]], test_scaled, split$test, model_name)
    classification_metrics_s14(split$test$target, probability) |> mutate(model = model_name, .before = 1)
  })) |> arrange(desc(roc_auc))

  selected_model <- metrics |> slice_head(n = 1) |> pull(model)
  selected_probability <- predict_s14_model(models[[selected_model]], test_scaled, split$test, selected_model)
  predictions <- split$test |>
    mutate(
      model = selected_model,
      predicted_probability = selected_probability,
      predicted_outcome = if_else(predicted_probability >= 0.5, 1L, 0L),
      predicted_label = factor(if_else(predicted_outcome == 1, "Heart disease", "No heart disease"), levels = c("No heart disease", "Heart disease"))
    )

  confusion <- predictions |>
    count(target_label, predicted_label, name = "records") |>
    complete(target_label, predicted_label, fill = list(records = 0))

  cv_metrics <- cross_validate_s14(split$train)
  roc_points <- roc_curve_points(predictions$target, predictions$predicted_probability)
  calibration <- calibration_bins(predictions$target, predictions$predicted_probability)

  logistic_coef <- coef(models$logistic)
  importance <- tibble(
    variable = names(logistic_coef)[-1],
    coefficient = as.numeric(logistic_coef[-1]),
    importance = abs(coefficient),
    direction = if_else(coefficient >= 0, "Higher probability", "Lower probability")
  ) |> arrange(desc(importance))

  write_csv(clean_data, s14_dir("data", "processed", "s14_clean_heart.csv"))
  write_csv(split$metadata, s14_dir("data", "processed", "s14_split_metadata.csv"))
  write_csv(metrics, s14_dir("data", "processed", "s14_model_metrics.csv"))
  write_csv(confusion, s14_dir("data", "processed", "s14_confusion_matrix.csv"))
  write_csv(cv_metrics, s14_dir("data", "processed", "s14_cv_metrics.csv"))
  write_csv(predictions, s14_dir("data", "processed", "s14_holdout_predictions.csv"))
  write_csv(roc_points, s14_dir("data", "processed", "s14_roc_curve.csv"))
  write_csv(calibration, s14_dir("data", "processed", "s14_calibration_bins.csv"))
  write_csv(importance, s14_dir("data", "processed", "s14_variable_importance.csv"))

  make_s14_figures(clean_data, roc_points, importance, calibration)
  invisible(list(metrics = metrics, selected_model = selected_model, predictions = predictions, cv_metrics = cv_metrics))
}
