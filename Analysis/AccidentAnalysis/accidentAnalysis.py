import pandas as pd
import json
from collections import defaultdict

def process_accidents_data(file_path, output_json_path):
   
    chunk_size = 100000
    accident_grid = defaultdict(lambda: {
        'lat': 0.0,
        'lng': 0.0,
        'count': 0,
        'injuries': 0,
        'deaths': 0,
        'factors': defaultdict(int)
    })

    total_rows = 0
    valid_coordinates = 0

    for chunk in pd.read_csv(file_path, chunksize=chunk_size, dtype={'ZIP CODE': str}):
        print(f"Processing chunk... (rows processed so far: {total_rows})")

        valid_chunk = chunk.dropna(subset=['LATITUDE', 'LONGITUDE'])
        valid_coordinates += len(valid_chunk)

        for _, row in valid_chunk.iterrows():
            try:
                lat = round(float(row['LATITUDE']), 3)
                lng = round(float(row['LONGITUDE']), 3)
                key = f"{lat},{lng}"

                if accident_grid[key]['count'] == 0:
                    accident_grid[key]['lat'] = lat
                    accident_grid[key]['lng'] = lng

                accident_grid[key]['count'] += 1
                accident_grid[key]['injuries'] += int(row.get('NUMBER OF PERSONS INJURED', 0) or 0)
                accident_grid[key]['deaths'] += int(row.get('NUMBER OF PERSONS KILLED', 0) or 0)

                factor = row.get('CONTRIBUTING FACTOR VEHICLE 1')
                if isinstance(factor, str) and factor.lower() != 'unspecified':
                    accident_grid[key]['factors'][factor] += 1
            except ValueError:
                continue  # Skip any malformed rows

        total_rows += len(chunk)

    heatmap_data = []
    for key, data in accident_grid.items():
        top_factors = sorted(
            [{'factor': k, 'count': v} for k, v in data['factors'].items()],
            key=lambda x: x['count'],
            reverse=True
        )[:3]

        heatmap_data.append({
            'lat': data['lat'],
            'lng': data['lng'],
            'count': data['count'],
            'injuries': data['injuries'],
            'deaths': data['deaths'],
            'topFactors': top_factors
        })

    heatmap_data.sort(key=lambda x: (x['deaths'] * 10) + x['injuries'] + (x['count'] * 0.1), reverse=True)

    result = {
        'heatmapData': heatmap_data,
        'totalRecords': total_rows,
        'validCoordinates': valid_coordinates,
        'metadata': {
            'gridPrecision': 3,
            'totalHotspots': len(heatmap_data)
        }
    }

    with open(output_json_path, 'w') as f:
        json.dump(result, f, indent=4)

    print(f"Analysis complete. Processed {total_rows} total records.")
    print(f"Found {valid_coordinates} records with valid coordinates.")
    print(f"Identified {len(heatmap_data)} unique hotspots.")
    print(f"Results saved to {output_json_path}")

    return result

def get_top_accident_locations(result_data, top_n=10):
    
    for i, spot in enumerate(result_data['heatmapData'][:top_n]):
        print(f"\n{i+1}. Location: ({spot['lat']}, {spot['lng']})")
        print(f"   Total accidents: {spot['count']}")
        print(f"   Injuries: {spot['injuries']}")
        print(f"   Deaths: {spot['deaths']}")
        if spot['topFactors']:
            print("   Top contributing factors:")
            for factor in spot['topFactors']:
                print(f"     - {factor['factor']}: {factor['count']} incidents")

csv_file_path = ""  # Update with actual path
output_path = "" #.json path
result = process_accidents_data(csv_file_path, output_path)
get_top_accident_locations(result)