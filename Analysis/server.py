import base64
import io
from flask import Flask, request, jsonify
import matplotlib
import pandas as pd
from flask_cors import CORS
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import seaborn as sns
import joblib
import logging
from datetime import datetime, timedelta, timezone

from dashb import traffic
from blockage import scrape_blockage
from json_read import json_to_csv
from peak import peak_hour_func
matplotlib.use('Agg')  # Use a non-GUI backend

from paths import (
    VOLUME_DATA_PATH,
    TRAFFIC_MODEL_PATH,
    VOLUME_DATASET_PATH,
    ACCIDENT_DATA_PATH,
    SPEEDS_DATA_PATH
)


app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Volume data
df = pd.read_csv(VOLUME_DATA_PATH)
# Load trained model
model = joblib.load(TRAFFIC_MODEL_PATH)


# Load dataset
vdf = pd.read_csv(VOLUME_DATASET_PATH) #it stores the cleaned data with weather

df['Yr'] = df['Yr'].astype(str)
df['M'] = df['M'].astype(str)
df['D'] = df['D'].astype(str)

df['date'] = df[['Yr', 'M', 'D']].agg('-'.join, axis=1)

# Accident data
df_acc = pd.read_csv(ACCIDENT_DATA_PATH)
df_acc['Hour'] = pd.to_datetime(df_acc['Time'], format='%H:%M:%S').dt.hour  # Hour column

# Speeds dataset
import json
# Read the JSON file
with open(SPEEDS_DATA_PATH, 'r') as f:
    data = json.load(f)
# Convert to DataFrame
speeds = json_to_csv(data)

@app.route('/traffic-analysis', methods=['GET','POST'])
def traffic_analysis():
    dashboard = traffic(df, df_acc)
    return dashboard

@app.route("/street_analysis", methods=["GET"])
def street_analysis():
    street = request.args.get("street")     #fetch street name from req

    if not street:
        return jsonify({"error": "Street name required"}), 400

    # filter the datasets for the input street, so processing kum ho jayega
    street_data = df[df["street"].str.upper() == street.upper()]  # Case insensitive            # Volume data
    street_acc = df_acc[df_acc["Street Name"].str.upper() == street.upper()]        # Accidents data
    street_speed = speeds[speeds["street_name"].str.upper() == street.upper()]        # Speeds dataset (Tom Tom august 24)

    street_name = street.upper()
    boro = street_data['Boro'].unique()         # take the first boro


    # blockage dataset
    block = scrape_blockage()       # returns cleaned scraped df
    blocked = block[block['From Street'].str.lower().str.contains(street.lower()) | block['To Street'].str.lower().str.contains(street.lower())]    #filtered for street
    blocked['To Date'] = pd.to_datetime(blocked['To Date'], errors='coerce')
    blocked['month'] = pd.to_datetime(blocked['From Date'], errors='coerce').dt.month


    if boro.ndim > 1:
        boro = boro[0]

    response = {}
    response["street_name"] = street_name
    if not blocked.empty:
        # total_blockages = blocked['Reason'].nunique()
        total_blockages = blocked.groupby(['Reason', 'From Street', 'To Street', 'From Date', 'To Date'])['Time'].count().count()  #gives total unique blockages from data
        active_blockages = blocked[blocked['To Date'] >= pd.Timestamp.today()].to_dict(orient='records')    # gives blockages whoes end date are yet to come ,.. thus active
        com_reason = blocked['Reason'].value_counts().head(5).to_dict()        # gives most common reasons of blockage
        monthly_blockages = blocked.groupby('month').size()

        plt.figure(figsize=(10, 6))
        monthly_blockages.plot(kind='bar')
        plt.title(f"Monthly Blockage Patterns for {street}")
        plt.xlabel("Month")
        plt.ylabel("Number of Blockages")
        img_io = io.BytesIO()
        plt.savefig(img_io, format="png", bbox_inches="tight")
        img_io.seek(0)
        monthly_pattern = base64.b64encode(img_io.getvalue()).decode("utf-8")
        plt.close()

        response["blockages"] = {
            "total_blockages": int(total_blockages),
            "active_blockages": active_blockages,
            "com_reason": com_reason,
            "monthly_pattern":monthly_pattern,
        }

    if not street_data.empty:
        # return jsonify({"error": "No data found for this street"}), 404
        # Most congested hour
        most_congested = dict(
            street_data.groupby('street').apply(lambda x: x.groupby('HH')['Vol'].mean().agg(['idxmax','max'])).reset_index()
            .to_dict()
        ) 

        # Least congested hour
        least_congested = dict(
            street_data.groupby('street').apply(lambda x: x.groupby('HH')['Vol'].mean().agg(['idxmin','min'])).reset_index()
            .to_dict()
        )

        # Volume in boro
        # boro_volume = dict(street_data.groupby('Boro').apply(lambda x: x[x['Boro'] == boro])['Vol'].mean().to_dict())

        # Traffic volume per hour plot
        plt.figure(figsize=(12, 6))
        sns.lineplot(data=street_data.groupby(by=['street','HH'])['Vol'].mean().reset_index(), x="HH", y="Vol")
        plt.xlabel("Hour of the Day")
        plt.ylabel("Average Traffic Volume")
        plt.title(f"Traffic Volume for {street}")
        plt.xticks(rotation=45)

        img_io = io.BytesIO()
        plt.savefig(img_io, format="png", bbox_inches="tight")
        img_io.seek(0)
        img_base64 = base64.b64encode(img_io.getvalue()).decode("utf-8")
        plt.close()

        response["volume_metrics"] = {
            "most_congested_hour": most_congested,
            "least_congested_hour": least_congested,
            "hour_plot": img_base64,
        }

    if not street_acc.empty:
    #     return jsonify({"error": "No Accident data found for this street"}), 404
    # else:
        # -------------------------------------------
        # Calculate safety metrics
        total_accidents = len(street_acc)
        total_injuries = street_acc['Persons Injured'].sum()
        total_fatalities = street_acc['Persons Killed'].sum()
        if total_accidents > 0:
            severity_ratio = ((total_injuries + total_fatalities) / total_accidents)
        else:
            severity_ratio = 0

        # --------------------------------------------
        # Hourly Accidents
        hourly_accidents = street_acc.groupby('Hour').size().reset_index(name='Accident_Count')

        # Find the hour with the most accidents
        peak_hour = hourly_accidents['Accident_Count'].idxmax()
        colors = [mcolors.to_rgba('red', 1.0) if hour == peak_hour else mcolors.to_rgba('pink') for hour in hourly_accidents['Hour']]

        # Plot accidents by hour
        plt.figure(figsize=(10, 5))
        sns.barplot(x=hourly_accidents['Hour'], y=hourly_accidents['Accident_Count'], palette=colors)
        plt.xlabel("Hour of the Day")
        plt.ylabel("Number of Accidents")
        plt.title("Accidents by Hour of the Day")
        plt.xticks(range(24))
        plt.grid(axis='y', linestyle='--', alpha=0.7)

        img_io = io.BytesIO()
        plt.savefig(img_io, format="png", bbox_inches="tight")
        img_io.seek(0)
        accidents = base64.b64encode(img_io.getvalue()).decode("utf-8")
        plt.close()
        # -------------------------------------------

        # -------------------------------------------
        # Weekly Accidents
        weekly_accidents = 1
        # street_acc['Day_of_Week'].value_counts()

        # plt.figure(figsize=(10, 5))
        # sns.barplot(x=weekly_accidents.index, y=weekly_accidents.values, palette="viridis")
        # plt.xlabel("Day of the Week")
        # plt.ylabel("Number of Accidents")
        # plt.title("Accidents by Day of the Week")
        # plt.xticks(rotation=45)
        # plt.grid(axis='y', linestyle='--', alpha=0.7)

        # img_io = io.BytesIO()
        # plt.savefig(img_io, format="png", bbox_inches="tight")
        # img_io.seek(0)
        # weekly_accidents_img = base64.b64encode(img_io.getvalue()).decode("utf-8")
        # plt.close()
        # -------------------------------------------

        # -------------------------------------------
        # Most Involved Vehicle Types
        vehicle_types = street_acc['Vehicle Type'].value_counts().head(10)

        plt.figure(figsize=(10, 5))
        sns.barplot(x=vehicle_types.values, y=vehicle_types.index, palette="coolwarm")
        plt.xlabel("Number of Accidents")
        plt.ylabel("Vehicle Type")
        plt.title("Top 10 Vehicle Types Involved in Accidents")
        plt.grid(axis='x', linestyle='--', alpha=0.7)

        img_io = io.BytesIO()
        plt.savefig(img_io, format="png", bbox_inches="tight")
        img_io.seek(0)
        vehicle_types_img = base64.b64encode(img_io.getvalue()).decode("utf-8")
        plt.close()
        # -------------------------------------------
        response["safety_metrics"] = {
        "vehicle_types": vehicle_types_img,
        "total_accidents": int(total_accidents),
        "total_injuries": int(total_injuries),
        "total_fatalities": int(total_fatalities),
        "severity_ratio": round(severity_ratio, 2),
        "accidents": accidents,
        }
    
        if not street_data.empty:
            street_acc['Hour'] = pd.to_datetime(street_acc['Time'], format='%H:%M:%S').dt.hour  # Extract hour
            hourly_accidents = street_acc.groupby(['Street Name', 'Hour']).size().reset_index(name='accident_count')

            hourly_volume = street_data.groupby(['street', 'HH'])['Vol'].mean().reset_index()
            # Convert street names to lowercase for consistency
            hourly_volume['street'] = hourly_volume['street'].str.lower()
            hourly_accidents['Street Name'] = hourly_accidents['Street Name'].str.lower()
            merged_data = pd.merge(
                hourly_volume,
                hourly_accidents,
                left_on=['street', 'HH'],
                right_on=['Street Name', 'Hour'],
                how='left'
            )
            merged_data = merged_data[merged_data['Street Name'].notna()]       #remove unmatched rows with NaN
            corr = merged_data['Vol'].corr(merged_data['accident_count'])
            
            plt.figure(figsize=(8,6))
            # Scatter plot with trend line
            sns.regplot(x=merged_data['Vol'], y=merged_data['accident_count'], 
                        scatter_kws={'s': 10, 'alpha': 0.5},  # Adjust dot size and transparency
                        line_kws={'color': 'red'},  # Make the trend line red
                        lowess=False)  # Use locally weighted regression for a smooth trend
            plt.xlabel("Traffic Volume")
            plt.ylabel("Accident Count")
            plt.title("Traffic Volume vs Accident Count with Trend Line")
            img = io.BytesIO()
            plt.savefig(img, format='png')
            img.seek(0)
            corr_scatter = base64.b64encode(img.getvalue()).decode()
            response['correlation'] = {
                "corr":corr,
                "corr_scatter":corr_scatter,
            }

        if not street_data.empty:
            risk_analysis = peak_hour_func(street, street_data, street_acc)
            response['risk_analysis'] = risk_analysis




    if not street_speed.empty:
    #     return jsonify({"error": "No Speed data found for this street"}), 404
    # else:
        # Get average speeds and volumes by hour
        hourly_volume = street_data.groupby('HH')['Vol'].mean().reset_index()
        
        # Calculate speed to volume ratio (this will require some data matching logic)
        avg_speed = street_speed['average_speed'].mean()
        speed_limit = street_speed['speed_limit'].mean() if 'speed_limit' in street_speed.columns else "Unknown"
        
        # Plot average speed vs volume
        plt.figure(figsize=(10, 6))
        sns.lineplot(data=hourly_volume, x='HH', y='Vol', marker='o', label='Volume')
        plt.title(f"Traffic Volume vs Hour for {street}")
        plt.xlabel("Hour of Day")
        plt.ylabel("Average Volume")
        plt.xticks(range(0, 24))
        
        if avg_speed:
            # Add a horizontal line for average speed
            plt.axhline(y=avg_speed, color='r', linestyle='--', label=f'Avg Speed: {avg_speed:.1f} mph')
            
        plt.legend()
        
        img_io = io.BytesIO()
        plt.savefig(img_io, format="png", bbox_inches="tight")
        img_io.seek(0)
        speed_volume_plot = base64.b64encode(img_io.getvalue()).decode("utf-8")
        plt.close()

        # --------------------------------------

        # street_data['date'] = pd.to_datetime(street_data['date'])
        # df_acc['Date'] = pd.to_datetime(df_acc['Date'])
        
        # # Monthly volume trends
        # monthly_volumes = street_data.groupby(pd.Grouper(key='date', freq='M'))['Vol'].mean().reset_index()
        # monthly_volumes = monthly_volumes.rename(columns={'date': 'Month', 'Vol': 'Average Volume'})
        
        # # Monthly accident trends
        # monthly_accidents = street_acc.groupby(pd.Grouper(key='Date', freq='M')).size().reset_index(name='Accident Count')
        
        # # Plot the trends
        # fig, ax1 = plt.subplots(figsize=(12, 6))
        
        # ax1.set_xlabel('Month')
        # ax1.set_ylabel('Average Volume', color='tab:blue')
        # ax1.plot(monthly_volumes['Month'], monthly_volumes['Average Volume'], color='tab:blue', marker='o')
        # ax1.tick_params(axis='y', labelcolor='tab:blue')
        
        # # Create a second y-axis
        # ax2 = ax1.twinx()
        # ax2.set_ylabel('Accident Count', color='tab:red')
        # ax2.plot(monthly_accidents['Date'], monthly_accidents['Accident Count'], color='tab:red', marker='x')
        # ax2.tick_params(axis='y', labelcolor='tab:red')
        
        # plt.title(f"Volume and Accident Trends for {street}")
        # fig.tight_layout()
        
        # img_io = io.BytesIO()
        # plt.savefig(img_io, format="png", bbox_inches="tight")
        # img_io.seek(0)
        # trend_plot = base64.b64encode(img_io.getvalue()).decode("utf-8")
        # plt.close()



    return jsonify(response)
    #     
    #     # ---------------------
    #     # "trend_analysis": {
    #     #     "trend_plot": trend_plot,
    #     #     "volume_growth": float(monthly_volumes.iloc[-1]['Average Volume'] / monthly_volumes.iloc[0]['Average Volume'] - 1) 
    #     #         if len(monthly_volumes) > 1 else None,
    #     #     "accident_growth": float(monthly_accidents.iloc[-1]['Accident Count'] / monthly_accidents.iloc[0]['Accident Count'] - 1)
    #     #         if len(monthly_accidents) > 1 else None
    #     # },
    #     "risk_analysis":,
    #     # "boro_volume": boro_volume,
    #     # "weekly_accidents": weekly_accidents_img,
    # })

# from flask import Flask, jsonify, request
# import joblib
# import pandas as pd
# from flask_cors import CORS
# from datetime import datetime, timedelta, timezone

# app = Flask(__name__)
# CORS(app)

# # Load trained model
# model = joblib.load(TRAFFIC_MODEL_PATH)

# # Load dataset
# vdf = pd.read_csv(VOLUME_DATASET_PATH)

# Function to predict traffic without weather data
# def predict_traffic(lat, lon, hour, minute):
#     input_data = pd.DataFrame([{
#         'HH': hour,
#         'MM': minute
#     }])  #  No weather features included

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

#  Route 1: Predict Traffic for All Streets (Without Weather)
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

#  Route 2: Predict Traffic for User's Selected Route (Without Weather)
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

#  Route 3: Predict Future Traffic Change (30-60 min ahead)
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
#             "change_percent": round(change_percent, 2)  #  Round to 2 decimal places
#         })

#     return jsonify(predictions)

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000,debug=True)



