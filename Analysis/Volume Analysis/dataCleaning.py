import pandas as pd
import numpy as np
from tqdm import tqdm
import paths

#----------------------------------------CLEANING DATASET----------------------------------------

file_path = paths.VOLUME_DATA_PATH  
chunksize = 100000 
cleaned_data = []


def clean_chunk(chunk):
    
    chunk = chunk.drop_duplicates()

    
    chunk['Vol'] = chunk['Vol'].fillna(0)  
    chunk = chunk.dropna(subset=['Boro', 'street', 'fromSt', 'toSt'])  

   
    chunk['DateTime'] = pd.to_datetime(
        chunk[['Yr', 'M', 'D', 'HH', 'MM']].rename(columns={
            'Yr': 'year', 'M': 'month', 'D': 'day', 'HH': 'hour', 'MM': 'minute'
        }), errors='coerce'
    )

    
    chunk = chunk.dropna(subset=['DateTime'])

    
    return chunk.reset_index(drop=True)


for chunk in tqdm(pd.read_csv(file_path, chunksize=chunksize)):
    cleaned_data.append(clean_chunk(chunk))


cleaned_df = pd.concat(cleaned_data, ignore_index=True)
cleaned_df['Date'] = pd.to_datetime(cleaned_df['DateTime']).dt.date



#--------------------Fetching unique-------------------
unique_df = cleaned_df[['WktGeom', 'Date']].drop_duplicates()

# Step 2: Merge back the 'street', 'Latitude', and 'Longitude' columns
# We use an inner merge to add the first match of 'WktGeom' and 'Date'
result_df = unique_df.merge(cleaned_df[['WktGeom', 'Date', 'street', 'Latitude', 'Longitude']],
                            on=['WktGeom', 'Date'],
                            how='inner').drop_duplicates()


result_df.to_csv(f'unique_fields.csv', index=False)



