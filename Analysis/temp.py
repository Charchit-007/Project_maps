import base64
import io
from flask import Flask, request, jsonify
import matplotlib
import pandas as pd
from flask_cors import CORS
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import seaborn as sns

from json_read import json_to_csv
from peak import peak_hour_func
matplotlib.use('Agg')  # Use a non-GUI backend


app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Volume data
df = pd.read_csv("Automated_Traffic_Volume_Counts_20250127.csv")
df['Yr'] = df['Yr'].astype(str)
df['M'] = df['M'].astype(str)
df['D'] = df['D'].astype(str)

df['date'] = df[['Yr', 'M', 'D']].agg('-'.join, axis=1)

# Accident data
df_acc = pd.read_csv("C:/Traffic_Data_DM/traffic_project_data/NYC_Collisions/NYC_Collisions.csv")
df_acc['Hour'] = pd.to_datetime(df_acc['Time'], format='%H:%M:%S').dt.hour  # Hour column

# Speeds dataset
import json
# Read the JSON file
with open('C:/Traffic_Data_DM/traffic_project_data/speeds.json', 'r') as f:
    data = json.load(f)
# Convert to DataFrame
speeds = json_to_csv(data)

@app.route("/street_analysis", methods=["GET"])
def street_analysis():
    street = request.args.get("street")

    if not street:
        return jsonify({"error": "Street name required"}), 400

    street_data = df[df["street"].str.upper() == street.upper()]  # Case insensitive            # Volume data
    street_acc = df_acc[df_acc["Street Name"].str.upper() == street.upper()]        # Accidents data
    street_speed = speeds[speeds["street_name"].str.upper() == street.upper()]        # Speeds dataset (Tom Tom august 24)

    street_name = street.upper()
    boro = street_data['Boro'].unique()         # take the first boro
    if boro.ndim > 1:
        boro = boro[0]
    response = {}
    if not street_data.empty:
        # return jsonify({"error": "No data found for this street"}), 404
        # errors["street_data"] = "No data found for this street"
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
        sns.barplot(data=street_data.groupby(by=['street','HH'])['Vol'].mean().reset_index(), x="HH", y="Vol")
        plt.xlabel("Hour of the Day")
        plt.ylabel("Average Traffic Volume")
        plt.title(f"Traffic Volume for {street}")
        plt.xticks(rotation=45)

        img_io = io.BytesIO()
        plt.savefig(img_io, format="png", bbox_inches="tight")
        img_io.seek(0)
        img_base64 = base64.b64encode(img_io.getvalue()).decode("utf-8")
        plt.close()


    if not street_acc.empty:
        # return jsonify({"error": "No Accident data found for this street"}), 404
        # errors["street_acc"] = "No Accident found for this street"
        # -------------------------------------------
        # Calculate safety metrics
        total_accidents = len(street_acc)
        total_injuries = street_acc['Persons Injured'].sum()
        total_fatalities = street_acc['Persons Killed'].sum()
        if total_accidents > 0:
            severity_ratio = (total_injuries + total_fatalities) / total_accidents
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

    if not street_speed.empty:
        # return jsonify({"error": "No Speed data found for this street"}), 404
        # errors["street_speed"] = "No Speed data found for this street"
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

    risk_analysis = peak_hour_func(street, street_data, street_acc)
  
    if response:
        return jsonify(response)
    return jsonify({
        "street_name": street_name,
        "most_congested_hour": most_congested,
        "least_congested_hour": least_congested,
        "hour_plot": img_base64,
        "accidents": accidents,
        "vehicle_types": vehicle_types_img,
        # ---------------------
        "safety_metrics":{
            "total_accidents": int(total_accidents),
            "total_injuries": int(total_injuries),
            "total_fatalities": int(total_fatalities),
            "severity_ratio": round(severity_ratio, 2),
        },
        # "trend_analysis": {
        #     "trend_plot": trend_plot,
        #     "volume_growth": float(monthly_volumes.iloc[-1]['Average Volume'] / monthly_volumes.iloc[0]['Average Volume'] - 1) 
        #         if len(monthly_volumes) > 1 else None,
        #     "accident_growth": float(monthly_accidents.iloc[-1]['Accident Count'] / monthly_accidents.iloc[0]['Accident Count'] - 1)
        #         if len(monthly_accidents) > 1 else None
        # },
        "risk_analysis":risk_analysis,
        # "boro_volume": boro_volume,
        # "weekly_accidents": weekly_accidents_img,
    })

if __name__ == "__main__":
    app.run(debug=True)
