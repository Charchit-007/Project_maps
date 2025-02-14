import pandas as pd
import json
from typing import List, Dict

def json_to_csv(json_data: Dict) -> pd.DataFrame:
    """
    Parse TomTom traffic data JSON into a pandas DataFrame
    focusing on segment results and their time measurements
    """
    # Extract segment results
    segments = json_data['network']['segmentResults']
    
    # Initialize lists to store flattened data
    flat_data = []
    
    for segment in segments:
        # Basic segment data with safe get operations
        base_data = {
            'segment_id': segment.get('segmentId'),
            'new_segment_id': segment.get('newSegmentId'),
            'speed_limit': segment.get('speedLimit'),
            'frc': segment.get('frc'),
            'distance': segment.get('distance')
        }
        
        # Add optional street name if present
        if 'streetName' in segment:
            base_data['street_name'] = segment['streetName']
            
        # Add coordinates if shape data exists
        if 'shape' in segment and len(segment['shape']) > 0:
            base_data.update({
                'start_lat': segment['shape'][0].get('latitude'),
                'start_lon': segment['shape'][0].get('longitude'),
                'end_lat': segment['shape'][-1].get('latitude'),
                'end_lon': segment['shape'][-1].get('longitude')
            })
        
        # Add time-based metrics if they exist
        if 'segmentTimeResults' in segment and len(segment['segmentTimeResults']) > 0:
            time_results = segment['segmentTimeResults'][0]  # Taking first time result
            metrics = {
                'harmonic_avg_speed': time_results.get('harmonicAverageSpeed'),
                'median_speed': time_results.get('medianSpeed'),
                'average_speed': time_results.get('averageSpeed'),
                'std_dev_speed': time_results.get('standardDeviationSpeed'),
                'sample_size': time_results.get('sampleSize'),
                'avg_travel_time': time_results.get('averageTravelTime'),
                'median_travel_time': time_results.get('medianTravelTime'),
                'travel_time_ratio': time_results.get('travelTimeRatio'),
                'speed_percentiles': str(time_results.get('speedPercentiles', []))  # Convert list to string for DataFrame
            }
            base_data.update(metrics)
        
        flat_data.append(base_data)
    
    return pd.DataFrame(flat_data)

# Example usage:
# with open('traffic_data.json', 'r') as f:
#     data = json.load(f)
# df = json_to_csv(data)

