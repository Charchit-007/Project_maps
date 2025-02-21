from sklearn.metrics import mean_absolute_error, r2_score
import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor


# Load dataset
df = pd.read_csv(r"C:\DM Project\volume_dataset.csv")  # Ensure your dataset is in CSV format

# Feature selection
features = ['HH', 'MM', 'temp_max', 'temp_min', 'precipitation', 'rain', 'snow', 'windspeed_max']
target = 'Vol'

# Drop rows with missing values
df = df.dropna()
model = joblib.load(r"C:\DM Project\traffic_model.pkl")
# Train-test split
X_train, X_test, y_train, y_test = train_test_split(df[features], df[target], test_size=0.2, random_state=42)
y_pred = model.predict(X_test)

# Calculate Mean Absolute Error (MAE)
mae = mean_absolute_error(y_test, y_pred)
print(f"Mean Absolute Error: {mae}")

# Calculate R² Score
r2 = r2_score(y_test, y_pred)
print(f"R² Score: {r2}")