# Raw Data Notes

This folder stores the raw CSV used by S13 when the workflow is executed locally.

## Canonical Source

The canonical dataset is the Kaggle Pima Indians Diabetes Database:

<https://www.kaggle.com/datasets/uciml/pima-indians-diabetes-database>

Expected file:

```text
diabetes.csv
```

## Local Build Source

The Kaggle CLI is not installed in this environment, so the script downloads a public CSV mirror when the canonical Kaggle file is not already present:

<https://raw.githubusercontent.com/npradaschnor/Pima-Indians-Diabetes-Dataset/master/diabetes.csv>

Kaggle remains the canonical source cited in the analysis.

## Git Policy

Raw data files are ignored by Git. Keep this README and the download instructions versioned.
