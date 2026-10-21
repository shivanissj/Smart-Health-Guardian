from fastapi import FastAPI
import pandas as pd
import joblib

app = FastAPI()

# Load trained model
model = joblib.load('model.pkl')
scaler = joblib.load('scaler.pkl')
encoder = joblib.load('encoder.pkl')

FEATURE_ORDER = [
    'HeartRate',
    'SpO2',
    'Age',
    'Gender',
    'Hypertension',
    'Diabetes',
    'Asthma',
    'Allergies',
    'PreviousEmergency',
    'AverageHR',
    'AverageSpO2',
    'MaximumHR',
    'MinimumSpO2'
]

@app.get('/')
def home():
    return {'status': 'ML API Running'}

@app.post('/predict')
def predict(data: dict):
    # Ensure correct feature order
    row = {key: data[key] for key in FEATURE_ORDER}
    df = pd.DataFrame([row])

    # Scale
    scaled = scaler.transform(df)

    # Predict
    pred = model.predict(scaled)
    probs = model.predict_proba(scaled)

    risk = encoder.inverse_transform(pred)[0]
    confidence = float(max(probs[0]))

    return {
        'risk': risk,
        'confidence': round(confidence * 100, 2)
    }