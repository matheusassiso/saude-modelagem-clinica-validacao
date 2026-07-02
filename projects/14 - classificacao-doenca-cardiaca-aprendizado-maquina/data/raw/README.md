# Raw Data Notes

This folder stores the raw CSV used by S14 when the workflow is executed locally.

## Canonical Source

The canonical source is the Kaggle Heart Disease Dataset:

<https://www.kaggle.com/datasets/johnsmith88/heart-disease-dataset>

Expected local file:

```text
heart.csv
```

## Local Build Source

The Kaggle CLI is not installed in this environment, so the script downloads a public CSV mirror when the canonical Kaggle file is not already present:

<https://raw.githubusercontent.com/kb22/Heart-Disease-Prediction/master/dataset.csv>

Kaggle remains the canonical source cited in the analysis.

## Git Policy

Raw data files are ignored by Git. Keep this README and the download instructions versioned.
