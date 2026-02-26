# Weather Feature Setup Instructions

The weather feature has been successfully integrated into Pal Low Voltage Pro!

**Two APIs Used:**
- **OpenWeatherMap** (free tier) - Current weather & 5-day forecast
- **National Weather Service** (completely free) - Real-time Indiana weather alerts

## 1. Get Your Free OpenWeatherMap API Key

1. Go to [https://openweathermap.org/api](https://openweathermap.org/api)
2. Click "Sign Up" (top right)
3. Create a free account
4. After signing in, go to "API keys" section
5. Copy your API key (it may take a few minutes to activate)

**Note:** The free tier includes:
- Current weather data
- 5-day / 3-hour forecast
- 1,000 API calls per day (more than enough for this app)

## 2. Add Your API Key to the App

1. Open `WeatherService.swift` in Xcode
2. Find this line (around line 18):
   ```swift
   private let apiKey = "YOUR_API_KEY_HERE"
   ```
3. Replace `YOUR_API_KEY_HERE` with your actual API key:
   ```swift
   private let apiKey = "abc123your456actual789key"
   ```
4. Save the file

## 3. Build and Run

1. Build the app in Xcode (Cmd + B)
2. Run on your device or simulator
3. Open the Weather tab from the home screen
4. Pull down to refresh if needed

## Features Included

### Current Weather
- Real-time temperature for Indianapolis area
- "Feels like" temperature
- Weather condition with icon
- High/Low temperatures
- Humidity percentage
- Wind speed

### 5-Day Forecast
- Daily high and low temperatures
- Weather conditions for each day
- Icons showing weather type
- Detailed descriptions

### Weather Alerts (FREE!)
- Severe weather warnings (if active)
- Watch notifications
- Advisory information
- Detailed descriptions and instructions
- Alert expiration times
- Affected areas

**Source:** National Weather Service (NWS) - Completely free, no API key required! The app fetches real-time alerts for Indiana from the official government weather service.

## Location

The weather is configured for:
- **Location:** Indianapolis, Indiana
- **Coordinates:** 39.7684° N, 86.1581° W

To change the location, edit the `latitude` and `longitude` values in `WeatherService.swift` (lines 13-14).

## Troubleshooting

### "Unable to load weather" Error
- Check that your API key is correct
- Wait a few minutes after creating your OpenWeatherMap account (keys need to activate)
- Check your internet connection
- Free tier has 1,000 calls/day limit - check if you've exceeded it

### No Weather Alerts Showing
- This is normal! Alerts only appear when there are active weather warnings/watches in Indiana
- Alerts are fetched from the National Weather Service (completely free)
- Check the current alerts at https://api.weather.gov/alerts/active/area/IN

### Weather Icons Not Loading
- Make sure you have an internet connection
- Icons load from OpenWeatherMap's servers
- They should appear after a brief loading delay

## Data Refresh

- Weather data refreshes automatically when you open the Weather view
- Pull down to manually refresh
- Tap the refresh button (↻) in the top right
- "Updated X ago" timestamp shows when data was last fetched

Enjoy your new weather feature!
