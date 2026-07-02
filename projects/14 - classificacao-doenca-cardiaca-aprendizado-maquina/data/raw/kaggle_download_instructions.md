# Kaggle Download Instructions

Use these steps when the Kaggle CLI is available.

1. Create or download a Kaggle API token from your Kaggle account settings.
2. Place `kaggle.json` in the standard Kaggle configuration folder.
3. Run from the project root:

```powershell
kaggle datasets download -d johnsmith88/heart-disease-dataset -p data/raw --unzip
```

The resulting file is commonly named:

```text
heart.csv
```

If the Kaggle CLI is unavailable, `prepare_s14_outputs()` downloads the public CSV mirror documented in `README.md`.
