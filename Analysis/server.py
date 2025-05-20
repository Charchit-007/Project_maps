import base64
import io
from flask import Flask, request, jsonify
import matplotlib
import pandas as pd
from flask_cors import CORS
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import requests
import seaborn as sns
import joblib

from datetime import datetime, timedelta, timezone

# functions 
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


app = Flask(__name__)    #  flask app banata hai
CORS(app)  # Enable CORS for all routes

# Load trained model
# model = joblib.load(TRAFFIC_MODEL_PATH)

# Load dataset
# vdf = pd.read_csv(VOLUME_DATASET_PATH) #it stores the cleaned data with weather

# Speeds dataset
import json

# with open(SPEEDS_DATA_PATH, 'r') as f:
#     data = json.load(f)
# speeds = json_to_csv(data)

# Volume data
df = pd.read_csv(VOLUME_DATA_PATH)
df['Yr'] = df['Yr'].astype(str)     # convert to string
df['M'] = df['M'].astype(str)
df['D'] = df['D'].astype(str)

df['date'] = df[['Yr', 'M', 'D']].agg('-'.join, axis=1)     #new col added with combind date

# Accident data
df_acc = pd.read_csv(ACCIDENT_DATA_PATH)
df_acc['Hour'] = pd.to_datetime(df_acc['Time'], format='%H:%M:%S').dt.hour  # Hour column
# converts 'Time' to datetime obj, and extracts hr part using dt.hour


@app.route('/traffic-analysis', methods=['GET','POST'])
def traffic_analysis():
    dashboard = traffic(df, df_acc)
    return dashboard


@app.route("/blockages", methods=["GET"])
def blockage():             # same code as Street analysis blockage
    # blockage dataset
    street = request.args.get("street")     #fetch street name from req
    if not street:
        return jsonify({"error": "Street name required"}), 400
    
    block = scrape_blockage()       # returns cleaned scraped df
    blocked = block[block['From Street'].str.lower().str.contains(street.lower()) | block['To Street'].str.lower().str.contains(street.lower())]    #filtered for street
    blocked['To Date'] = pd.to_datetime(blocked['To Date'], errors='coerce')        #ensures that invalid dates are set to NaT to avoid errors
    blocked['month'] = pd.to_datetime(blocked['From Date'], errors='coerce').dt.month

    response = {}
    response["street_name"] = street
    if not blocked.empty:   
        # total_blockages = blocked['Reason'].nunique()
        total_blockages = blocked.groupby(['Reason', 'From Street', 'To Street', 'From Date', 'To Date'])['Time'].count().count()  #gives total unique blockages from data
        active_blockages = blocked[blocked['To Date'] >= pd.Timestamp.today()].to_dict(orient='records')    # gives blockages whose end date are yet to come ,.. thus active
        # orient - converts the DataFrame into a list of dictionaries, where each row(record) becomes a dictionary
        com_reason = blocked['Reason'].value_counts().head(5).to_dict()        # gives most common reasons of blockage
        response["blockages"] = {
            "total_blockages": int(total_blockages),
            "active_blockages": active_blockages,
            "com_reason": com_reason,
        }

    return(response)

@app.route("/street_analysis", methods=["GET"])         #as were fetching the street input from the UI
def street_analysis():
    street = request.args.get("street")     #fetch street name from req

    if not street:
        return jsonify({"error": "Street name required"}), 400

    # filter the datasets for the input street, so processing kum ho jayega
    street_data = df[df["street"].str.upper() == street.upper()]  # Case insensitive            # Volume data
    street_acc = df_acc[df_acc["Street Name"].str.upper() == street.upper()]        # Accidents data
    # street_speed = speeds[speeds["street_name"].str.upper() == street.upper()]        # Speeds dataset (Tom Tom august 24)

    street_name = street.upper()
    boro = street_data['Boro'].unique()         # take the first boro


    # blockage dataset
    block = scrape_blockage()       # returns cleaned scraped df
    blocked = block[block['From Street'].str.lower().str.contains(street.lower()) | block['To Street'].str.lower().str.contains(street.lower())]    #filtered for street
    blocked['To Date'] = pd.to_datetime(blocked['To Date'], errors='coerce')        #ensures that invalid dates are set to NaT to avoid errors
    blocked['month'] = pd.to_datetime(blocked['From Date'], errors='coerce').dt.month


    if boro.ndim > 1:
        boro = boro[0]

    response = {}
    response["street_name"] = street_name
    if not blocked.empty:
        # total_blockages = blocked['Reason'].nunique()
        total_blockages = blocked.groupby(['Reason', 'From Street', 'To Street', 'From Date', 'To Date'])['Time'].count().count()  #gives total unique blockages from data
        active_blockages = blocked[blocked['To Date'] >= pd.Timestamp.today()].to_dict(orient='records')    # gives blockages whose end date are yet to come ,.. thus active
        # orient - converts the DataFrame into a list of dictionaries, where each row(record) becomes a dictionary
        com_reason = blocked['Reason'].value_counts().head(5).to_dict()        # gives most common reasons of blockage
        # to dict makes it easy to work with json 
        monthly_blockages = blocked.groupby('month').size()

        plt.figure(figsize=(10, 6)) # w x h
        monthly_blockages.plot(kind='bar')
        plt.title(f"Monthly Blockage Patterns for {street}")
        plt.xlabel("Month")
        plt.ylabel("Number of Blockages")
        img_io = io.BytesIO()
        # saves image in binary stream .. so as to avoid saving as a file on disk
        plt.savefig(img_io, format="png", bbox_inches="tight")
        img_io.seek(0)   # moves pointer to the start of bytes stream to avoid errors
        monthly_pattern = base64.b64encode(img_io.getvalue()).decode("utf-8")       # encode in base64 format and decode it to a string
        # encode and decode as josn doesnt support binary data, 
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
        # to_dict might give pandas specific dictionary ... dict() helps ensure its a standard python dictionary
        #  used this, as got an error once that, json was unable to read the response on flutter ... it had a problem with invalid dictionary format

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

    # Safety metrics
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
            # eg -> 1.7 -> each accident results in 1.7 injuries or fatalities
        else:   
            severity_ratio = 0

        # --------------------------------------------
        # Hourly Accidents
        hourly_accidents = street_acc.groupby('Hour').size().reset_index(name='Accident_Count')

        # find the hour with the most accidents
        peak_hour = hourly_accidents['Accident_Count'].idxmax()
        colors = [mcolors.to_rgba('red', 1.0) if hour == peak_hour else mcolors.to_rgba('pink') for hour in hourly_accidents['Hour']]

        # plot accidents by hour
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
        # weekly_accidents = 1
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
                how='left'          #keeps all rows from hourly_volume (traffic volume data), even if no accidents occurred for that hour
            )
            merged_data = merged_data[merged_data['Street Name'].notna()]       #remove unmatched rows with NaN
            corr = merged_data['Vol'].corr(merged_data['accident_count'])
            
            plt.figure(figsize=(8,6))
            # Scatter plot with trend line
            sns.regplot(x=merged_data['Vol'], y=merged_data['accident_count'], 
                        scatter_kws={'s': 10, 'alpha': 0.5},  # Adjust dot size and transparency
                        line_kws={'color': 'red'},  # Make the trend line red
                        lowess=False)  # Use locally weighted regression for a smooth trend
            # A linear regression trend line shows the overall pattern.
            # If sloped upwards → More traffic leads to more accidents.

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

    return(response)

def fetch_weather_data():
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": 40.7128,  # New York City Latitude
        "longitude": -74.0060,  # New York City Longitude
        "hourly": ["temperature_2m", "precipitation", "windspeed_10m"],
        "current_weather": True,
        "timezone": "America/New_York"
    }
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        current_weather = data.get("current_weather", {})
        return {
            "temp_max": current_weather.get("temperature", 25),
            "temp_min": current_weather.get("temperature", 15),
            "precipitation": current_weather.get("precipitation", 0.1),
            
            "rain": 1 if current_weather.get("precipitation", 0) > 0 else 0,
            "snow": 0 ,
            "windspeed_max": current_weather.get("windspeed", 15),
        }
    except requests.RequestException as e:
        print(f"Weather API request failed: {e}")
        return {  # Dummy fallback data
            "temp_max": 25,
            "temp_min": 15,
            "precipitation": 0.1,
            "rain": 0,
            "snow": 0,
            "windspeed_max": 15
        }

weather_data = fetch_weather_data()
"""
def predict_traffic(lat,lon,hour, minute):
    try:
        input_data = pd.DataFrame([{ 
    "Latitude": lat, 
    "Longitude": lon, 
    "HH": hour, 
    "MM": minute, 
    **weather_data 
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
"""
if __name__ == '__main__':          #prevents the server from starting unintentionally when the file is not the main file
    # The file you execute using python <filename>.py is treated as the main file.
    app.run(host="0.0.0.0", port=5000, debug=True)              #"0.0.0.0" -> server accessible from any device on netwrk 
    # we used 0.0.0.0 as we were facing some error without it. 
# ye ensures karega that script runs only when executed directly (not when imported as a module)



