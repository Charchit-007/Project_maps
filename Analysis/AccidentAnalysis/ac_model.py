import joblib
import pandas as pd

from flask_cors import CORS
import json
import numpy as np

# Load accident data
with open(r"C:\Project_maps\assets\nyc_accident_hotspots.json", "r") as f:
    accident_data = json.load(f)["heatmapData"]

df_accidents = pd.DataFrame(accident_data)

# Train a simple model for severity prediction
# Define severity levels
conditions = [
    (df_accidents["deaths"] > 5) | (df_accidents["injuries"] > 1000),
    (df_accidents["deaths"] > 1) | (df_accidents["injuries"] > 500),
    (df_accidents["deaths"] == 0) & (df_accidents["injuries"] <= 500),
]
choices = ["High", "Moderate", "Low"]
df_accidents["severity"] = np.select(conditions, choices, default="Low")

# Train a simple model
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier

X = df_accidents[["count", "injuries", "deaths"]]
y = df_accidents["severity"]
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Save model
joblib.dump(model, r"C:\DM Project\ac_model.pkl")