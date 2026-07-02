# Kaggle Download Instructions

Use these steps when the Kaggle CLI is available.

1. Create or download a Kaggle API token from your Kaggle account settings.
2. Place `kaggle.json` in the standard Kaggle configuration folder.
3. Run from the project root:

```powershell
kaggle datasets download -d uciml/pima-indians-diabetes-database -p data/raw --unzip
```

The resulting file should be:

```text
data/raw/diabetes.csv
```

If the Kaggle CLI is unavailable, `prepare_s13_outputs()` downloads the public CSV mirror documented in `README.md`.
