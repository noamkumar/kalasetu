import logging
from typing import Any, Dict, Optional
import httpx

logger = logging.getLogger("kalasetu.weather")

WMO_WEATHER_CODES = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Foggy",
    48: "Depositing rime fog",
    51: "Light drizzle",
    53: "Moderate drizzle",
    55: "Dense drizzle",
    61: "Slight rain",
    63: "Moderate rain",
    65: "Heavy rain",
    71: "Slight snow",
    73: "Moderate snow",
    75: "Heavy snow",
    80: "Slight rain showers",
    81: "Moderate rain showers",
    82: "Violent rain showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail",
    99: "Thunderstorm with heavy hail",
}

class WeatherService:
    """Live weather integration using Open-Meteo API.
    
    100% free, no API key required, reliable worldwide and Indian coverage.
    """

    GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search"
    FORECAST_URL = "https://api.open-meteo.com/v1/forecast"

    @classmethod
    async def get_weather_for_location(
        cls,
        city_name: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        timeout: float = 6.0
    ) -> Optional[Dict[str, Any]]:
        """Fetches real-time weather observations for a named city or coordinates."""
        city = (city_name or "").strip()
        lat, lon = latitude, longitude

        async with httpx.AsyncClient(timeout=timeout) as client:
            # 1. Geocode city if coordinates are not provided
            if (lat is None or lon is None) and city:
                try:
                    resp = await client.get(
                        cls.GEOCODING_URL,
                        params={"name": city, "count": 1, "language": "en", "format": "json"}
                    )
                    if resp.status_code == 200:
                        data = resp.json()
                        results = data.get("results", [])
                        if results:
                            lat = float(results[0]["latitude"])
                            lon = float(results[0]["longitude"])
                            city = results[0].get("name", city)
                            country = results[0].get("country", "India")
                except Exception as e:
                    logger.warning(f"Geocoding error for '{city}': {e}")

            # Default to Hyderabad, India if no location found
            if lat is None or lon is None:
                lat, lon = 17.3850, 78.4867
                city = city or "Hyderabad"

            # 2. Fetch current weather from Open-Meteo
            try:
                params = {
                    "latitude": lat,
                    "longitude": lon,
                    "current": "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,is_day",
                    "timezone": "auto",
                }
                resp = await client.get(cls.FORECAST_URL, params=params)
                if resp.status_code == 200:
                    current = resp.json().get("current", {})
                    weather_code = current.get("weather_code", 0)
                    condition = WMO_WEATHER_CODES.get(weather_code, "Pleasant")

                    return {
                        "status": "success",
                        "city": city,
                        "latitude": lat,
                        "longitude": lon,
                        "temperature_c": current.get("temperature_2m"),
                        "feels_like_c": current.get("apparent_temperature"),
                        "humidity_pct": current.get("relative_humidity_2m"),
                        "precipitation_mm": current.get("precipitation", 0.0),
                        "wind_kmh": current.get("wind_speed_10m"),
                        "condition": condition,
                        "weather_code": weather_code,
                        "is_day": current.get("is_day") == 1,
                        "time": current.get("time"),
                    }
            except Exception as e:
                logger.warning(f"Forecast fetch failed: {e}")

        return None
