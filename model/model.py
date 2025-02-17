import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor

# Load dataset
df = pd.read_csv(r"model\volume_dataset.csv")  # Ensure your dataset is in CSV format

# Feature selection
features = ['HH', 'MM', 'temp_max', 'temp_min', 'precipitation', 'rain', 'snow', 'windspeed_max']
target = 'Vol'

# Drop rows with missing values
df = df.dropna()

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(df[features], df[target], test_size=0.2, random_state=42)

# Train model
model = RandomForestRegressor(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Save model
joblib.dump(model, 'traffic_model.pkl')
