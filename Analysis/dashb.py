from flask import Flask, jsonify
from flask_cors import CORS
import pandas as pd
import logging
import matplotlib
matplotlib.use('Agg')  # Prevent Tkinter issues in Flask
import matplotlib.pyplot as plt  # Import pyplot AFTER setting backend

import base64
from io import BytesIO

logging.basicConfig(level=logging.DEBUG)

def generate_base64_plot(fig):
    """Converts a Matplotlib figure to a base64-encoded string."""
    buf = BytesIO()
    fig.savefig(buf, format="png")
    buf.seek(0)
    return base64.b64encode(buf.getvalue()).decode("utf-8")

def traffic(df, df_acc):
    try:
        traffic_data =df
        collision_data = df_acc

        # Borough-wise congestion
        boro_congestion = traffic_data.groupby("Boro")["Vol"].sum().sort_values(ascending=False).to_dict()

        # Hourly traffic volume
        hourly_traffic = traffic_data.groupby("HH")["Vol"].sum().sort_values(ascending=True).to_dict()

        # Top 3 busiest hours per borough
        busiest_hours = {}
        busiest_hours_graphs = {}
        boroughs = traffic_data["Boro"].unique()
        for boro in boroughs:
            boro_df = traffic_data[traffic_data["Boro"] == boro]
            top_hours = boro_df.groupby("HH")["Vol"].sum().nlargest(3).to_dict()
            busiest_hours[boro] = top_hours

            fig, ax = plt.subplots()
            ax.bar(top_hours.keys(), top_hours.values(), color="blue")
            ax.set_xlabel("Hour of the Day")
            ax.set_ylabel("Traffic Volume")
            ax.set_title(f"Top 3 Busiest Hours in {boro}")
            graph_base64 = generate_base64_plot(fig)
            plt.close(fig)
            busiest_hours_graphs[boro] = graph_base64

        # Traffic by 3-hour intervals per borough (Now Separate Graphs)
        traffic_data["Hour_Group"] = (traffic_data["HH"] // 3) * 3
        boro_hourly_traffic = {}
        # boro_hourly_graphs = {}

        for boro in boroughs:
            boro_df = traffic_data[traffic_data["Boro"] == boro]
            hourly_counts = boro_df.groupby("Hour_Group")["Vol"].sum().to_dict()
            boro_hourly_traffic[boro] = hourly_counts
            print("Hourly counts  ----- ",boro_hourly_traffic)

            # fig, ax = plt.subplots()
            # ax.bar(hourly_counts.keys(), hourly_counts.values(), color="green")
            # ax.set_xlabel("Hour Group (Every 3 Hours)")
            # ax.set_ylabel("Traffic Volume")
            # ax.set_title(f"Traffic by 3-Hour Intervals in {boro}")

            # graph_base64 = generate_base64_plot(fig)
            # plt.close(fig)
            # boro_hourly_graphs[boro] = graph_base64

        # Convert date column to datetime
        collision_data["Date"] = pd.to_datetime(collision_data["Date"])
        collision_data["Month"] = collision_data["Date"].dt.to_period("M")

        # Top 5 accident-prone streets per borough
        accident_hotspots = {}
        accident_hotspots_graphs = {}
        for boro in boroughs:
            boro_df = collision_data[collision_data["Borough"] == boro]
            top_streets = (
                boro_df.groupby("Street Name").size()
                .nlargest(5)
                .to_dict()
            )
            accident_hotspots[boro] = top_streets

            # fig, ax = plt.subplots()
            # ax.barh(list(top_streets.keys()), list(top_streets.values()), color="red")
            # ax.set_xlabel("Accident Count")
            # ax.set_title(f"Top 5 Dangerous Streets in {boro}")
            # graph_base64 = generate_base64_plot(fig)
            # plt.close(fig)
            # accident_hotspots_graphs[boro] = graph_base64
        print(f"accident_hotspots",accident_hotspots)
        

        # Most common causes of accidents
        common_causes = collision_data["Contributing Factor"].value_counts().to_dict()
        print(f"common causes : {common_causes}  --- ")

        # Accidents by vehicle type
        accidents_by_vehicle = collision_data["Vehicle Type"].value_counts().to_dict()

        logging.debug("Data processing complete.")

        return jsonify({
            "Borough-wise Congestion": boro_congestion,
            "Hourly Traffic Volume": hourly_traffic,
            "Traffic by 3-Hour Intervals": boro_hourly_traffic,
            # "Traffic by 3-Hour Intervals Graphs": boro_hourly_graphs,
            "Top 3 Busiest Hours": busiest_hours,
            "Top 3 Busiest Hours Graphs": busiest_hours_graphs,
            "Top 5 Dangerous Streets": accident_hotspots,
            # "Top 5 Dangerous Streets Graphs": accident_hotspots_graphs,
            "Most Common Causes of Accidents": common_causes,
            "Accidents by Vehicle Type": accidents_by_vehicle
        })
    except Exception as e:
        logging.error(f"Error processing data: {e}")
        return jsonify({"error": "Failed to process data"}), 500
