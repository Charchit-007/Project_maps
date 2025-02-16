import base64
import io
from flask import Flask, request, jsonify
import matplotlib
import pandas as pd
from flask_cors import CORS
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import seaborn as sns


def peak_hour_func(street, street_data, street_acc):
    # Get hourly volumes and accidents
    
    hourly_volumes = street_data.groupby('HH')['Vol'].sum().reset_index()
    hourly_accidents = street_acc.groupby('Hour').size().reset_index(name='Accidents')

    # Merge the data
    hourly_analysis = pd.merge(hourly_volumes, hourly_accidents, left_on='HH', right_on='Hour', how='outer').fillna(0)
    hourly_analysis = hourly_analysis.rename(columns={'HH': 'Hour1', 'Vol': 'Average Volume'})

    # # Calculate risk ratio (accidents per volume)
    hourly_analysis['Risk Ratio'] = (hourly_analysis['Accidents'] / hourly_analysis['Average Volume']) * 1000  # per 1000 vehicles

 
    # # Find the riskiest hour
    riskiest_hour = hourly_analysis.sort_values('Risk Ratio', ascending=False).reset_index()
    print(riskiest_hour)
    # Plot risk ratio by hour
    plt.figure(figsize=(12, 6))
    sns.lineplot(data=hourly_analysis, x='Hour1', y='Risk Ratio')
    plt.axvline(x=int(riskiest_hour.loc[0, 'Hour1']), 
                color='red', linestyle='--', 
                label=f"Riskiest Hour: {int(riskiest_hour.loc[0, 'Hour1'])}:00")
    plt.title(f"Accident Risk by Hour for {street}")
    plt.xlabel("Hour of Day")
    plt.ylabel("Accidents per 1000 Vehicles")
    plt.legend()
    
    img_io = io.BytesIO()
    plt.savefig(img_io, format="png", bbox_inches="tight")
    img_io.seek(0)
    risk_plot = base64.b64encode(img_io.getvalue()).decode("utf-8")
    plt.close()

    return{
            "riskiest_hour": int(riskiest_hour.loc[0, 'Hour1']),
            "risk_ratio": float(riskiest_hour.loc[0, 'Risk Ratio']),
            "risk_plot": risk_plot,
            "peak_volume_hour": int(hourly_analysis.loc[hourly_analysis['Average Volume'].idxmax()]['Hour']),
            "peak_accident_hour": int(hourly_analysis.loc[hourly_analysis['Accidents'].idxmax()]['Hour'])
        }
