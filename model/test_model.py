import pandas as pd
import joblib
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import numpy as np


df = pd.read_csv(r"C:\DM Project\volume_dataset.csv")  

features = ['Latitude', 'Longitude', 'HH', 'MM', 'temp_max', 'temp_min', 'precipitation', 'rain', 'snow', 'windspeed_max']
target = 'Vol'


df = df.dropna()


from sklearn.model_selection import train_test_split
_, X_test, _, y_test = train_test_split(df[features], df[target], test_size=0.2, random_state=42)


model = joblib.load(r'C:\DM Project\traffic_model_new.pkl')

y_pred = model.predict(X_test)

# metrics
mae = mean_absolute_error(y_test, y_pred)
mse = mean_squared_error(y_test, y_pred)
rmse = np.sqrt(mse)
r2 = r2_score(y_test, y_pred)

# Print results
print(f"Model Performance Metrics:")
print(f"Mean Absolute Error (MAE): {mae:.2f}")
print(f"Mean Squared Error (MSE): {mse:.2f}")
print(f"Root Mean Squared Error (RMSE): {rmse:.2f}")
print(f"R² Score: {r2:.4f}")


results = pd.DataFrame({'Actual': y_test[:10].values, 'Predicted': y_pred[:10]})
print("\nSample Predictions:")
print(results)
