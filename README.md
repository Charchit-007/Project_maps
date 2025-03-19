# RoutEx - NYC Traffic Monitoring & Analysis App

**RoutEx** is a traffic monitoring and analysis application built to enhance navigation and promote safer travel across New York City. By delivering real-time traffic insights, intelligent route planning, and accident-prone zone alerts, RoutEx empowers users to make informed and efficient travel decisions.

## Overview

RoutEx leverages historical traffic data, real-time updates, and accident reports to provide a comprehensive view of congestion patterns and high-risk areas. It integrates multiple reliable data sources including:

- **NYC OpenData** – Traffic speed and volume data
- **Maven Analytics** – Detailed accident reports
- **Open-Meteo** – Real-time weather data
- **NYC.gov** – Road closure and advisory updates

## Key Features

### ● Real-time Traffic Updates  
Stay updated with current traffic conditions, congestion levels, and volume trends.

### ● Route Planning & Optimization  
Plan the fastest and safest route using **OpenStreetMap** data, avoiding congestion and accident zones.

### ● Accident-Prone Zone Alerts  
Receive alerts when your route passes through areas with a high frequency of accidents.

### ● Heatmap of Accidents  
Visualize accident hotspots with interactive heatmaps based on aggregated historical data.

### ● Historical Traffic Data Analysis  
Explore past traffic patterns, analyze congestion trends, and understand peak traffic times.

### ● Road Closures & Blockage Alerts  
Get notified about road closures and blockages using advisory updates from NYC.gov.

---

## Tech Stack

### Frontend (Mobile App) – *Flutter*
- **Flutter** – Cross-platform mobile development framework
- **flutter_map** – OpenStreetMap integration for route mapping
- **flutter_heatmap** – Visualize accident hotspots using heatmaps
- **syncfusion_flutter_charts** – Display graphs and charts for traffic trends and analysis

### Backend (API & Data Processing) – *Flask*
- **Flask** – Lightweight Python web framework for handling APIs
- **JSON** – Data format for communication between backend and frontend

### Data Processing & Machine Learning
- **Pandas** – Data manipulation and analysis
- **NumPy** – Numerical computations and matrix operations
- **Matplotlib** – Static data visualization
- **Seaborn** – Statistical data visualization
- **RandomForest** – Machine learning model for traffic prediction
- **joblib** – Model serialization for efficient loading and deployment

---

## Summary

RoutEx is designed with the goal of improving urban mobility by helping users avoid traffic bottlenecks and accident-prone areas. Whether you're commuting daily or planning a trip through NYC, RoutEx ensures your journey is safer and more efficient.