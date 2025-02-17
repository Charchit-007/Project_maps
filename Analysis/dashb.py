
from flask import jsonify


def traffic(df, df_acc):
    # from flask import Flask, jsonify
    # from flask_cors import CORS  # Import CORS
    import pandas as pd
    import logging
        
    # Enable logging for debugging
    logging.basicConfig(level=logging.DEBUG)

    try:
        # Load datasets
        traffic_data = df
        collision_data = df_acc
        
        # Borough-wise congestion
        boro_congestion = traffic_data.groupby("Boro")["Vol"].sum().sort_values(ascending=False).to_dict()
        
        # Hourly traffic
        hourly_traffic = traffic_data.groupby("HH")["Vol"].sum().sort_values(ascending=True).to_dict()
        
        # Traffic by 3-hour intervals per borough
        traffic_data["Hour_Group"] = (traffic_data["HH"] // 3) * 3
        boroughs = traffic_data["Boro"].unique()
        boro_hourly_traffic = {}
        for boro in boroughs:
            boro_df = traffic_data[traffic_data["Boro"] == boro]
            hourly_volume = boro_df.groupby("Hour_Group")["Vol"].sum().to_dict()
            boro_hourly_traffic[boro] = hourly_volume
        
        # Convert date column to datetime
        collision_data["Date"] = pd.to_datetime(collision_data["Date"])
        collision_data["Month"] = collision_data["Date"].dt.to_period("M")
        
        # Top 10 dangerous streets
        top_streets = (
            collision_data.groupby(["Street Name", "Month"]).size()
            .reset_index(name="Accident_Count")
            .groupby("Street Name")["Accident_Count"]
            .sum()
            .nlargest(10)
            .to_dict()
        )
        
        # Most common causes of accidents
        common_causes = (
            collision_data["Contributing Factor"]
            .value_counts()
            .to_dict()
        )
        
        # Accidents by vehicle type
        accidents_by_vehicle = (
            collision_data["Vehicle Type"]
            .value_counts()
            .to_dict()
        )
        
        # Log data processing time (for debugging purposes)
        logging.debug("Data processing complete.")

        # Return all results as JSON
        return jsonify({
            "Borough-wise Congestion": boro_congestion,
            "Hourly Traffic Volume": hourly_traffic,
            "Traffic by 3-Hour Intervals": boro_hourly_traffic,
            "Top 10 Dangerous Streets": top_streets,
            "Most Common Causes of Accidents": common_causes,
            "Accidents by Vehicle Type": accidents_by_vehicle
        })
    except Exception as e:
        logging.error(f"Error processing data: {e}")
        return jsonify({"error": "Failed to process data"}), 500
