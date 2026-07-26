# AgriPoints — Crop Yield Prediction & Reward System

**Mission:** Inspire young people to engage in agricultural activities through a reward-based system that grants redeemable points for farming activities carried out (irrigating, applying fertilizer, choosing suitable crops for their soil/region). This project predicts crop yield from farming practices, so the reward engine can grant more points for practices shown to genuinely improve yield rather than practices that merely sound beneficial.

## Dataset

[Agriculture Crop Yield Dataset](https://www.kaggle.com/datasets/samuelotiattakorah/agriculture-crop-yield) (Kaggle) — 1,000,000 rows, 10 columns (Region, Soil Type, Crop, Rainfall, Temperature, Fertilizer/Irrigation use, Weather Condition, Days to Harvest, and the target: Yield in tons/hectare).

## Live API (Swagger UI)

**Public prediction API:** https://racheal-resty-akello-regression-analysis.onrender.com/docs

Test the `/predict` endpoint directly from the Swagger page above (click "Try it out"), or the `/retrain` endpoint by uploading a CSV of new labeled data.

## Video Demo

**YouTube link:** [ADD YOUR VIDEO LINK HERE]

## Repository Structure

```
summative/
├── linear_regression/
│   └── multivariate.ipynb      # Task 1: EDA, feature engineering, model training/comparison
├── API/
│   ├── prediction.py           # Task 2: FastAPI service (/predict, /retrain)
│   ├── requirements.txt
│   ├── runtime.txt
│   └── *.joblib                # trained model, scaler, feature columns
├── FlutterApp/                 # Task 3: mobile app
└── pyproject.toml
```

## Running the Mobile App

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (SDK >= 3.0.0) and make sure a device/emulator is available: `flutter devices`
2. From the repo root:
   ```bash
   cd summative/FlutterApp
   flutter pub get
   ```
3. Confirm the `baseUrl` constant near the top of `lib/main.dart` points to the live Render API above.
4. Run the app on your connected device/emulator:
   ```bash
   flutter run
   ```
5. Fill in the 9 fields (Region, Soil Type, Crop, Weather Condition, Rainfall, Temperature, Days to Harvest, Fertilizer Used, Irrigation Used) and tap **Predict**.

## Running the Notebook / API locally (optional)

This project uses [`uv`](https://docs.astral.sh/uv/) for Python package and virtual environment management.

**1. Install `uv`** (if not already installed):
```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Or via pip, on any OS
pip install uv
```
> If `uv` isn't recognized as a command after installing (a PATH issue), run it through Python instead: replace `uv` with `python -m uv` in the commands below — both work identically.

**2. Sync the environment and run the notebook:**
```bash
cd summative
uv sync
uv run jupyter notebook linear_regression/multivariate.ipynb
```

**3. Run the API locally:**
```bash
cd summative/API
uv run uvicorn prediction:app --reload
```
