from flask import Flask, jsonify, request
import joblib
import pandas as pd
from flask_cors import CORS
from datetime import datetime, timedelta, timezone

app = Flask(__name__)
CORS(app)

# Load trained model
model = joblib.load(r"model\traffic_model.pkl")

# Load dataset
vdf = pd.read_csv(r"model\volume_dataset.csv")

# Function to predict traffic without weather data
# def predict_traffic(lat, lon, hour, minute):
#     input_data = pd.DataFrame([{
#         'HH': hour,
#         'MM': minute
#     }])  # No weather features included

#     predicted_volume = model.predict(input_data)[0]
#     return predicted_volume

def predict_traffic(lat, lon, hour, minute):
    try:
        # Here you could add API call to get real weather data
        # For now using more realistic dummy values
        input_data = pd.DataFrame([{
            'HH': hour,
            'MM': minute,
            'temp_max': 25,  # More realistic default values
            'temp_min': 15,  # that could be updated with real
            'precipitation': 0.1,  # weather API data
            'rain': 0,
            'snow': 0,
            'windspeed_max': 15
        }])
        
        predicted_volume = model.predict(input_data)[0]
        return predicted_volume
        
    except Exception as e:
        print(f"Error predicting traffic: {e}")
        return 0 
    

# Define traffic colors based on volume
def get_traffic_color(volume):
    if volume > 100:
        return "red"
    elif volume > 50:
        return "yellow"
    else:
        return "green"

# ✅ Route 1: Predict Traffic for All Streets (Without Weather)
@app.route('/predict_all', methods=['GET'])
def predict_all():
    predictions = []

    for _, row in vdf.iterrows():
        lat, lon = row["Latitude"], row["Longitude"]
        current_hour = datetime.now().hour
        current_minute = datetime.now().minute

        volume = predict_traffic(lat, lon, current_hour, current_minute)
        traffic_color = get_traffic_color(volume)

        predictions.append({
            "street": row["street"],
            "latitude": lat,
            "longitude": lon,
            "traffic_color": traffic_color
        })

    return jsonify(predictions)

# ✅ Route 2: Predict Traffic for User's Selected Route (Without Weather)
@app.route('/predict_route', methods=['POST'])
def predict_route():
    data = request.json
    route_points = data.get("route_points", [])

    predictions = []

    for point in route_points:
        lat, lon = point["latitude"], point["longitude"]
        current_hour = datetime.now().hour
        current_minute = datetime.now().minute

        volume = predict_traffic(lat, lon, current_hour, current_minute)
        traffic_color = get_traffic_color(volume)

        predictions.append({
            "latitude": lat,
            "longitude": lon,
            "traffic_color": traffic_color
        })

    return jsonify(predictions)

# ✅ Route 3: Predict Future Traffic Change (30-60 min ahead)
@app.route('/predict_future', methods=['POST'])
def predict_future():
    data = request.json
    route_points = data.get("route_points", [])
    
    # Get current time
    current_time = datetime.now()
    future_time = current_time + timedelta(minutes=30)
    
    predictions = []
    
    for point in route_points:
        lat, lon = point["latitude"], point["longitude"]
        
        # Current traffic prediction
        current_volume = predict_traffic(
            lat, 
            lon, 
            current_time.hour,
            current_time.minute
        )
        
        # Future traffic prediction (properly handling hour rollover)
        future_volume = predict_traffic(
            lat,
            lon,
            future_time.hour,
            future_time.minute
        )
        
        # Calculate percentage change
        if current_volume > 0:
            change_percent = ((future_volume - current_volume) / current_volume) * 100
        else:
            change_percent = 0
            
        predictions.append({
            "latitude": lat,
            "longitude": lon,
            "current_volume": round(current_volume, 2),
            "future_volume": round(future_volume, 2),
            "change_percent": round(change_percent, 2)
        })
    
    return jsonify(predictions)
# def predict_future():
#     data = request.json
#     route_points = data.get("route_points", [])

#     predictions = []

#     for point in route_points:
#         lat, lon = point["latitude"], point["longitude"]
#         current_hour = datetime.now().hour
#         current_minute = datetime.now().minute

#         # Predict for current traffic
#         current_volume = predict_traffic(lat, lon, current_hour, current_minute)

#         # Predict for future traffic (30 min ahead)
#         future_volume = predict_traffic(lat, lon, current_hour, (current_minute + 30) % 60)

#         # Calculate percentage change
#         change_percent = ((future_volume - current_volume) / current_volume) * 100 if current_volume > 0 else 0

#         predictions.append({
#             "latitude": lat,
#             "longitude": lon,
#             "change_percent": round(change_percent, 2)  # ✅ Round to 2 decimal places
#         })

#     return jsonify(predictions)

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
