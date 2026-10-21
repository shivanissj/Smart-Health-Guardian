import joblib
import pandas as pd

model = joblib.load("model.pkl")
scaler = joblib.load("scaler.pkl")
encoder = joblib.load("encoder.pkl")

sample = {
    "HeartRate":85,
    "SpO2":98,
    "Age":72,
    "Gender":1,
    "Hypertension":1,
    "Diabetes":1,
    "Asthma":0,
    "Allergies":0,
    "PreviousEmergency":0,
    "AverageHR":84,
    "AverageSpO2":97,
    "MaximumHR":90,
    "MinimumSpO2":96
}

df = pd.DataFrame([sample])

df = scaler.transform(df)

prediction = model.predict(df)

risk = encoder.inverse_transform(prediction)

print(risk[0])