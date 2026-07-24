"""
AgriPoints Crop Yield Prediction API
"""

import io
import os

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Literal
from sklearn.linear_model import SGDRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error

# Load trained artifacts (produced by Task 1's notebook)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "best_model.joblib")
SCALER_PATH = os.path.join(BASE_DIR, "scaler.joblib")
FEATURES_PATH = os.path.join(BASE_DIR, "feature_cols.joblib")

model = joblib.load(MODEL_PATH)
scaler = joblib.load(SCALER_PATH)
feature_cols = joblib.load(FEATURES_PATH)

CAT_COLS = ["Region", "Soil_Type", "Crop", "Weather_Condition"]
BOOL_COLS = ["Fertilizer_Used", "Irrigation_Used"]
TARGET_COL = "Yield_tons_per_hectare"

# App + CORS
app = FastAPI(
    title="AgriPoints Crop Yield Prediction API",
    description="Predicts crop yield (tons/hectare) to power a rewards system "
    "that grants points for farming activities predicted to improve yield.",
    version="1.0.0",
)

# CORS reasoning:
# - allow_origins is an explicit whitelist (NOT "*"), because this API returns
#   predictions that will drive point allocations in a real app - we only want
#   requests from our own Flutter app's web build and our own admin dashboard,
#   not from arbitrary third-party sites that could scrape or abuse the model.
# - allow_methods is restricted to GET/POST only, since this API has no need
#   for PUT/DELETE/PATCH - the fewer verbs allowed, the smaller the attack surface.
# - allow_headers is restricted to Content-Type and Authorization, matching
#   what the Flutter app actually sends (a JSON body + optional auth token).
# - allow_credentials is True because a future version of the app may use
#   cookies/auth headers tied to a logged-in student's reward account.
ALLOWED_ORIGINS = [
    "http://localhost:3000",       # local web/dev testing
    "http://127.0.0.1:3000",
    "https://agripoints.app",      # placeholder: replace with your real deployed frontend domain
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)


# Pydantic request schema - enforced data types + realistic range constraints
class CropYieldInput(BaseModel):
    Region: Literal["East", "North", "South", "West"]
    Soil_Type: Literal["Chalky", "Clay", "Loam", "Peaty", "Sandy", "Silt"]
    Crop: Literal["Barley", "Cotton", "Maize", "Rice", "Soybean", "Wheat"]
    Weather_Condition: Literal["Cloudy", "Rainy", "Sunny"]

    Rainfall_mm: float = Field(..., ge=100.0, le=1000.0, description="Rainfall in mm, real dataset range 100-1000")
    Temperature_Celsius: float = Field(..., ge=15.0, le=40.0, description="Temperature in Celsius, real dataset range 15-40")
    Days_to_Harvest: int = Field(..., ge=60, le=149, description="Days to harvest, real dataset range 60-149")

    Fertilizer_Used: bool
    Irrigation_Used: bool

    class Config:
        json_schema_extra = {
            "example": {
                "Region": "North",
                "Soil_Type": "Loam",
                "Crop": "Wheat",
                "Weather_Condition": "Sunny",
                "Rainfall_mm": 600.0,
                "Temperature_Celsius": 25.0,
                "Days_to_Harvest": 120,
                "Fertilizer_Used": True,
                "Irrigation_Used": True,
            }
        }


class PredictionResponse(BaseModel):
    predicted_yield_tons_per_hectare: float


# Helper: turn a raw input dict into the encoded/scaled row the model expects
def preprocess(raw_input: dict) -> pd.DataFrame:
    row = pd.DataFrame([raw_input])
    for c in BOOL_COLS:
        row[c] = row[c].astype(int)
    row = pd.get_dummies(row, columns=CAT_COLS)
    row = row.reindex(columns=feature_cols, fill_value=0)
    return row


# Routes
@app.get("/")
def root():
    return {"status": "ok", "message": "AgriPoints Crop Yield Prediction API is running."}


@app.post("/predict", response_model=PredictionResponse)
def predict(payload: CropYieldInput):
    try:
        row = preprocess(payload.model_dump())
        row_scaled = scaler.transform(row)
        prediction = float(model.predict(row_scaled)[0])
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Prediction failed: {e}")
    return PredictionResponse(predicted_yield_tons_per_hectare=round(prediction, 3))


@app.post("/retrain")
async def retrain(file: UploadFile = File(...)):
    """
    Accepts a CSV of new labeled data (same columns as the original dataset,
    including the target column Yield_tons_per_hectare) and retrains the
    currently-deployed model on it, then overwrites the saved model file.

    This lets the reward system stay accurate as new farming activity data
    comes in from users, without redeploying the whole API.
    """
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file.")

    try:
        contents = await file.read()
        new_df = pd.read_csv(io.BytesIO(contents))

        required_cols = CAT_COLS + BOOL_COLS + ["Rainfall_mm", "Temperature_Celsius", "Days_to_Harvest", TARGET_COL]
        missing = [c for c in required_cols if c not in new_df.columns]
        if missing:
            raise HTTPException(status_code=400, detail=f"Missing required columns: {missing}")

        for c in BOOL_COLS:
            new_df[c] = new_df[c].astype(int)
        df_encoded = pd.get_dummies(new_df, columns=CAT_COLS)
        df_encoded = df_encoded.reindex(columns=feature_cols + [TARGET_COL], fill_value=0)

        X_new = df_encoded[feature_cols]
        y_new = df_encoded[TARGET_COL]

        X_train, X_test, y_train, y_test = train_test_split(X_new, y_new, test_size=0.2, random_state=42)
        X_train_scaled = scaler.transform(X_train)
        X_test_scaled = scaler.transform(X_test)

        global model
        new_model = SGDRegressor(max_iter=1000, learning_rate="invscaling", eta0=0.01, random_state=42)
        new_model.fit(X_train_scaled, y_train)

        new_mse = mean_squared_error(y_test, new_model.predict(X_test_scaled))

        joblib.dump(new_model, MODEL_PATH)
        model = new_model

        return {
            "message": "Model retrained successfully on new data.",
            "rows_used": len(new_df),
            "test_mse_after_retraining": round(float(new_mse), 4),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Retraining failed: {e}")