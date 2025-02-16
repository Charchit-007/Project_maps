import requests
from bs4 import BeautifulSoup
import pandas as pd
import re

def scrape_blockage():
    # Fetch webpage
    url = "https://www.nyc.gov/html/dot/html/motorist/wkndtraf.shtml"
    response = requests.get(url)
    soup = BeautifulSoup(response.text, "html.parser")

    # Lists to store extracted data
    boroughs, from_streets, to_streets, from_dates, to_dates, times, reasons = [], [], [], [], [], [], []

    # Finding all boroughs (h2 tags)
    for borough_tag in soup.find_all("h2"):
        borough = borough_tag.text.strip()

        # Find next sibling elements containing street details
        for strong_tag in borough_tag.find_all_next("strong"):
            street_name = strong_tag.text.strip()
            
            # Extract "From Street" and "To Street" using regex
            street_match = re.search(r"(.+?) between (.+)", street_name)
            if street_match:
                from_street, to_street_raw = street_match.groups()
            else:
                from_street, to_street_raw = street_name, "Unknown"

            # Split "To Street" if it contains "and"
            to_streets_list = [s.strip() for s in to_street_raw.split(" and ")]

            # The closure details are in the next paragraph (<p>)
            p_tag = strong_tag.find_next_sibling("p")
            if p_tag:
                details = p_tag.text.strip()
                
                # Extracting time, from_date, and to_date using regex
                time_match = re.search(r"(\d{1,2} (?:am|pm) to \d{1,2} (?:am|pm))", details)
                date_match = re.findall(r"(\d{1,2}/\d{1,2}/\d{2,4})", details)
                reason_match = re.search(r"for (.+)", details)

                # Assign extracted values
                time = time_match.group(1) if time_match else "Unknown"
                from_date = date_match[0] if len(date_match) > 0 else "Unknown"
                to_date = date_match[1] if len(date_match) > 1 else from_date  # If no second date, assume same as first
                reason = reason_match.group(1) if reason_match else "Unknown"

                # Store data for each "To Street" separately
                for to_street in to_streets_list:
                    boroughs.append(borough)
                    from_streets.append(from_street)
                    to_streets.append(to_street)
                    from_dates.append(from_date)
                    to_dates.append(to_date)
                    times.append(time)
                    reasons.append(reason)

    # Creating DataFrame
    df = pd.DataFrame({
        "Borough": boroughs,
        "From Street": from_streets,
        "To Street": to_streets,
        "From Date": from_dates,
        "To Date": to_dates,
        "Time": times,
        "Reason": reasons
    })

    boro = ["Brooklyn", "Staten Island", "Manhattan", "Bronx", "Queens", "Manhattan/Queens", "Brooklyn/Queens"]
    clean = df[(df['Borough'].isin(boro)) & df['Borough'].notna() & (df['Borough'] != 'Unknown')]
    return clean

    # Save to Excel
    # df.to_excel("nyc_traffic_advisories.xlsx", index=False, engine="openpyxl")
    print("File saved successfully!")
