import pandas as pd
import joblib

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score

from xgboost import XGBClassifier

# Load dataset
df = pd.read_csv("SHG_dataset.csv")

# Convert RiskLabel to numbers
encoder = LabelEncoder()
df["RiskLabel"] = encoder.fit_transform(df["RiskLabel"])

# Features
X = df.drop("RiskLabel", axis=1)

# Target
y = df["RiskLabel"]

# Split
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.2,
    random_state=42
)

# Scale
scaler = StandardScaler()

X_train = scaler.fit_transform(X_train)
X_test = scaler.transform(X_test)

# Train model
model = XGBClassifier(
    n_estimators=200,
    max_depth=6,
    learning_rate=0.05,
    random_state=42
)

model.fit(X_train, y_train)

# Prediction
pred = model.predict(X_test)

accuracy = accuracy_score(y_test, pred)

print("Accuracy :", accuracy)

# Save
joblib.dump(model, "model.pkl")
joblib.dump(scaler, "scaler.pkl")
joblib.dump(encoder, "encoder.pkl")

print("Training Completed")