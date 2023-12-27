from flask import Flask, jsonify
import requests

app = Flask(__name__)

# Constants for Washington, D.C. coordinates (given in prompt)
LATITUDE = 38.9072
LONGITUDE = -77.0369
OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"


@app.route("/weather", methods=["GET"])
def get_weather():
    params = {"latitude": LATITUDE, "longitude": LONGITUDE, "current_weather": True}

    # Make call to the API using above params
    response = requests.get(OPEN_METEO_URL, params=params)
    return jsonify(response.json())


# Application is accessible from any IP address that the container can be reached at
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
