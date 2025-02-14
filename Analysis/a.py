import pandas as pd
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
import numpy as np
from datetime import datetime

RATE_LIMIT = 600  # Max API calls per minute


def get_daily_weather_data(latitude, longitude, date):
    """
    Fetch key daily historical weather data from Open Meteo API for traffic prediction

    :param latitude: Latitude of the location
    :param longitude: Longitude of the location
    :param date: Date to retrieve weather data for (format: YYYY-MM-DD)
    :return: Dictionary containing essential daily weather summary
    """
    base_url = "https://archive-api.open-meteo.com/v1/archive"

    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": date,
        "end_date": date,
        "daily": [
            "temperature_2m_max",
            "temperature_2m_min",
            "precipitation_sum",
            "rain_sum",
            "wind_speed_10m_max",
            "wind_direction_10m_dominant",
        ],
        "timezone": "America/New_York",
    }

    try:
        response = requests.get(base_url, params=params)
        response.raise_for_status()
        data = response.json()

        return {
            "date": date,
            "max_temperature": data['daily']['temperature_2m_max'][0],
            "min_temperature": data['daily']['temperature_2m_min'][0],
            "temperature_range": data['daily']['temperature_2m_max'][0] - data['daily']['temperature_2m_min'][0],
            "total_precipitation": data['daily']['precipitation_sum'][0],
            "total_rain": data['daily']['rain_sum'][0],
            "max_wind_speed": data['daily']['wind_speed_10m_max'][0],
            "dominant_wind_direction": data['daily']['wind_direction_10m_dominant'][0],
        }

    except requests.RequestException as e:
        print(f"Error fetching weather data for {date}: {e}")
        return None


def enrich_dataframe_with_weather(df, max_workers=10):
    """
    Enrich DataFrame with weather data using parallel processing

    :param df: Input pandas DataFrame
    :param max_workers: Maximum number of concurrent API calls
    :return: Enriched DataFrame
    """
    weather_cache = {}

    # Create weather columns
    weather_columns = [
        'max_temperature', 'min_temperature', 'temperature_range',
        'total_precipitation', 'total_rain',
        'max_wind_speed', 'dominant_wind_direction'
    ]

    for col in weather_columns:
        df[col] = np.nan

    unique_weather_queries = df.groupby(['Latitude', 'Longitude', 'Date']).first().reset_index()

    # Rate limiting variables
    call_count = 0
    start_time = time.time()

    def fetch_weather_for_row(row):
        nonlocal call_count, start_time

        date = row['Date']
        key = (row['Latitude'], row['Longitude'], date)

        if key in weather_cache:
            return key, weather_cache[key]

        # Rate limit enforcement
        call_count += 1
        if call_count >= RATE_LIMIT:
            elapsed_time = time.time() - start_time
            if elapsed_time < 60:
                time.sleep(60 - elapsed_time)
            start_time = time.time()
            call_count = 0

        weather_data = get_daily_weather_data(row['Latitude'], row['Longitude'], date)

        if weather_data:
            weather_cache[key] = weather_data

        return key, weather_data

    # Parallel processing with thread pool
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_key = {
            executor.submit(fetch_weather_for_row, row):
            (row['Latitude'], row['Longitude'], row['Date'])
            for _, row in unique_weather_queries.iterrows()
        }

        for future in as_completed(future_to_key):
            key, weather_data = future.result()

            if weather_data:
                mask = (
                    (df['Latitude'] == key[0]) &
                    (df['Longitude'] == key[1]) &
                    (df['Date'] == key[2])
                )

                for col in weather_columns:
                    df.loc[mask, col] = weather_data.get(col)

    return df


# Example usage
def main():
    # Load your dataset
    df = pd.read_csv('C:/Users/anujv/OneDrive/Desktop/ImpCodingApps/traffic_project_data/unique_part_1.csv.xls')
    df = df.head()

    # Enrich with weather data
    enriched_df = enrich_dataframe_with_weather(df, max_workers=10)

    # Save the enriched dataset
    enriched_df.to_csv('enriched_dataset.csv', index=False)

    print("Dataset enriched with weather parameters!")


if __name__ == "_main_":
    main()
