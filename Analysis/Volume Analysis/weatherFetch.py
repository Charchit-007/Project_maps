#----------------------------------------------------------------------WEATHER DATA FETCHING-----------------------------------------------------------------

import pandas as pd
import requests
import time
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
from tqdm import tqdm

def parse_date(date_str):
    """Convert date string to YYYY-MM-DD format, handling multiple possible formats"""
    try:
        # first trying DD-MM-YYYY format
        return datetime.strptime(date_str, "%d-%m-%Y").strftime("%Y-%m-%d")
    except ValueError:
        try:
            # trying YYYY-MM-DD format
            datetime.strptime(date_str, "%Y-%m-%d")  # Validate the format
            return date_str  # Already in correct format
        except ValueError:
            # Try one more format: MM-DD-YYYY
            try:
                return datetime.strptime(date_str, "%m-%d-%Y").strftime("%Y-%m-%d")
            except ValueError:
                raise ValueError(f"Could not parse date: {date_str}. Expected formats: DD-MM-YYYY, YYYY-MM-DD, or MM-DD-YYYY")

# Cache for weather data to avoid duplicate requests
weather_cache = {}

def fetch_weather_data(lat, lon, date):
    """Fetch weather data for a specific location and date with caching"""
    cache_key = f"{lat}_{lon}_{date}"

    # Return cached result if available
    if cache_key in weather_cache:
        return weather_cache[cache_key]

    url = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": date,
        "end_date": date,
        "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,rain_sum,snowfall_sum,windspeed_10m_max",
        "timezone": "America/New_York" 
    }

    max_retries = 3
    retry_delay = 2  

    for attempt in range(max_retries):
        try:
            response = requests.get(url, params=params, timeout=10)

            if response.status_code == 200:
                data = response.json()
                daily_data = data.get('daily', {})

                # Get the first (and only) element for each weather parameter
                result = {
                    'temp_max': daily_data.get('temperature_2m_max', [None])[0],
                    'temp_min': daily_data.get('temperature_2m_min', [None])[0],
                    'precipitation': daily_data.get('precipitation_sum', [None])[0],
                    'rain': daily_data.get('rain_sum', [None])[0],
                    'snow': daily_data.get('snowfall_sum', [None])[0],
                    'windspeed_max': daily_data.get('windspeed_10m_max', [None])[0]
                }

                # Cache the result
                weather_cache[cache_key] = result
                return result

            elif response.status_code == 429:  # Too Many Requests
                if attempt < max_retries - 1:  
                    time.sleep(retry_delay * (attempt + 1))  
                    continue

            else:
                print(f"Error fetching data: {response.status_code}")
                break

        except (requests.exceptions.Timeout, requests.exceptions.ConnectionError) as e:
            if attempt < max_retries - 1:
                time.sleep(retry_delay * (attempt + 1))
                continue
            else:
                print(f"Failed after {max_retries} attempts: {str(e)}")

    # If all attempts failed, return None
    return None

def worker(row_data):
    """Worker function for parallel processing"""
    index, row = row_data
    date = parse_date(row['Date'])
    weather_data = fetch_weather_data(row['Latitude'], row['Longitude'], date)

    if weather_data:
        result = {'index': index}
        result.update(weather_data)
        return result
    return None

def process_file(file_path, output_path, max_workers=10):
    """Process a file with parallel processing and rate limiting"""
    print(f"Processing {file_path}...")

    
    df = pd.read_csv(file_path)
    total_rows = len(df)

    row_data = list(df.iterrows())

    pbar = tqdm(total=total_rows, desc="Fetching weather data")

   
    results = []
    request_times = []
    MAX_REQUESTS_PER_MINUTE = 550  # as openmeteo allows only 600 calls/min

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []

        for i, data in enumerate(row_data):
            
            now = time.time()
           
            request_times = [t for t in request_times if now - t < 60]

           
            if len(request_times) >= MAX_REQUESTS_PER_MINUTE:
                time_to_wait = 60 - (now - request_times[0])
                if time_to_wait > 0:
                    time.sleep(time_to_wait)

          
            request_times.append(time.time())

            # Submit the task
            future = executor.submit(worker, data)
            futures.append(future)

            # Update progress every 20 rows or at the end
            if (i + 1) % 20 == 0 or i == total_rows - 1:
                # Wait for completed futures and update progress
                done_futures = [f for f in futures if f.done()]
                for f in done_futures:
                    result = f.result()
                    if result:
                        results.append(result)
                    futures.remove(f)
                    pbar.update(1)

        # Wait for remaining futures
        for future in futures:
            result = future.result()
            if result:
                results.append(result)
            pbar.update(1)

    pbar.close()

    # Update the dataframe with results
    for result in results:
        index = result.pop('index')
        for key, value in result.items():
            df.loc[index, key] = value

    # Save the result
    df.to_csv(output_path, index=False)
    print(f"Saved result to {output_path}")

    return df



process_file("","")

