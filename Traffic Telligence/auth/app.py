from flask import Flask, request, render_template, jsonify, redirect, url_for
import os
import random
import smtplib
import googlemaps
from datetime import datetime
from email.mime.text import MIMEText
from pymongo import MongoClient
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from xgboost import XGBRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from dotenv import load_dotenv
load_dotenv()

app = Flask(__name__)

# ==========================================
# 1. CONFIGURATION & PATHS
# ==========================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_PATH = os.path.join(BASE_DIR, "traffic_volume.csv")

# Google Maps Setup (REPLACE WITH YOUR KEY)
GMAPS_KEY = os.getenv("GMAPS_API_KEY") 
gmaps = googlemaps.Client(key=GMAPS_KEY)

# MongoDB Setup
try:
    client = MongoClient('mongodb://localhost:27017/')
    db = client['APSCHE']
    users_collection = db['userdata']
except Exception as e:
    print(f"Error connecting to MongoDB: {e}")

# Email & OTP Setup
otp_store = {}
EMAIL_SENDER = "clginternshipacc@gmail.com"
EMAIL_PASSWORD = os.getenv("EMAIL_PASSWORD")

# ==========================================
# 2. HELPER FUNCTIONS & ML INITIALIZATION
# ==========================================
def send_email(email, otp):
    subject = "Traffic Telligence - Your OTP Code"
    message = f"Your OTP code for secure login is {otp}."
    msg = MIMEText(message)
    msg['Subject'] = subject
    msg['From'] = EMAIL_SENDER
    msg['To'] = email
    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(EMAIL_SENDER, EMAIL_PASSWORD)
            server.sendmail(EMAIL_SENDER, email, msg.as_string())
        return True
    except Exception as e:
        print(f"Error sending email: {e}")
        return False

def initialize_system():
    if not os.path.exists(DATASET_PATH):
        print(f"CRITICAL ERROR: Dataset not found at {DATASET_PATH}")
        return None, None, None, {}

    data = pd.read_csv(DATASET_PATH)
    le = LabelEncoder()
    data['weather'] = le.fit_transform(data['weather'].fillna('Clouds'))
    
    features = ['holiday', 'temp', 'rain', 'snow', 'weather', 'day', 'month', 'year', 'hours']
    target = 'traffic_volume'
    
    X = data[features]
    y = data[target]
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)
    
    sc = StandardScaler()
    X_train_scaled = sc.fit_transform(X_train)
    X_test_scaled = sc.transform(X_test)
    
    regressor = XGBRegressor(objective='reg:squarederror', n_estimators=100, random_state=42)
    regressor.fit(X_train_scaled, y_train)
    
    y_pred = regressor.predict(X_test_scaled)
    metrics = {
        "mae": round(mean_absolute_error(y_test, y_pred), 2),
        "rmse": round(np.sqrt(mean_squared_error(y_test, y_pred)), 2),
        "r2": round(r2_score(y_test, y_pred), 4)
    }
    return regressor, sc, le, metrics

model, scaler, weather_encoder, model_metrics = initialize_system()

# ==========================================
# 3. AUTHENTICATION ROUTES
# ==========================================
@app.route('/')
def index():
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        fname = request.form.get('fname')
        lname = request.form.get('lname')
        email = request.form.get('email')
        password = request.form.get('setPwd')
        confirm_password = request.form.get('confirmPwd')

        if not all([fname, lname, email, password, confirm_password]):
            return render_template('register.html', error="All fields are required.")
        if password != confirm_password:
            return render_template('register.html', error="Passwords do not match.")
        if users_collection.find_one({"email": email}):
            return render_template('register.html', error="User already registered.")

        users_collection.insert_one({
            "first_name": fname,
            "last_name": lname,
            "email": email,
            "password": password
        })
        return redirect(url_for('index', msg="Registration successful! Please login."))
    return render_template('register.html')

@app.route('/send-otp', methods=['POST'])
def send_otp():
    data = request.json
    email = data.get('email')
    password = data.get('password')

    user = users_collection.find_one({"email": email, "password": password})
    if not user:
        return jsonify({"message": "Invalid email or password"}), 401

    otp = random.randint(100000, 999999)
    otp_store[email] = otp

    if send_email(email, otp):
        return jsonify({"message": f"OTP sent to {email}"}), 200
    return jsonify({"message": "Failed to send OTP"}), 500

@app.route('/verify-otp', methods=['POST'])
def verify_otp():
    data = request.json
    email = data.get('email')
    otp_entered = int(data.get('otp', 0))

    if not email or email not in otp_store:
        return jsonify({"message": "Invalid email"}), 400

    if otp_store.get(email) == otp_entered:
        del otp_store[email]
        return jsonify({"message": "Login successful", "redirect": url_for('interface')}), 200

    return jsonify({"message": "Incorrect OTP. Try again"}), 400

# ==========================================
# 4. PREDICTION ROUTES
# ==========================================
@app.route('/interface')
def interface():
    # Pass both the metrics AND the API key to the template
    return render_template('interface.html', 
                           metrics=model_metrics, 
                           gmaps_key=GMAPS_KEY)

@app.route('/predict-live', methods=['POST'])
def predict_live():
    try:
        origin = request.form.get('origin')
        destination = request.form.get('destination')
        now = datetime.now()
        
        directions = gmaps.distance_matrix(origin, destination, mode="driving", departure_time=now)
        element = directions['rows'][0]['elements'][0]
        
        if element['status'] != 'OK':
            return render_template('interface.html', error="Route not found.", metrics=model_metrics)
            
        traffic_time = element['duration_in_traffic']['value']
        normal_time = element['duration']['value']
        congestion_ratio = traffic_time / normal_time

        live_input = pd.DataFrame([[
            0, now.hour + 273, 0.0, 0.0, 
            weather_encoder.transform(['Clouds'])[0],
            now.day, now.month, now.year, now.hour
        ]], columns=['holiday', 'temp', 'rain', 'snow', 'weather', 'day', 'month', 'year', 'hours'])

        scaled_input = scaler.transform(live_input)
        base_prediction = model.predict(scaled_input)[0]
        final_volume = base_prediction * congestion_ratio

        return render_template('result.html', 
                               volume=int(final_volume), # Converted to whole number of vehicles
                               ratio=round(congestion_ratio, 2),
                               origin=origin, destination=destination,
                               metrics=model_metrics, mode="Live Data")
    except Exception as e:
        return render_template('interface.html', error=f"Error: {str(e)}", metrics=model_metrics)

@app.route('/process', methods=['POST'])
def process():
    try:
        holiday = request.form.get('holiday', "0")
        temp = request.form.get('temp', "290")
        rain = request.form.get('rain', "0")
        snow = request.form.get('snow', "0")
        weather = request.form.get('weather', "Clouds")
        day = request.form.get('day', "1")
        month = request.form.get('month', "1")
        year = request.form.get('year', "2024")
        hours = request.form.get('hours', "12")

        input_data = pd.DataFrame([[
            int(holiday), float(temp), float(rain), float(snow),
            weather_encoder.transform([weather])[0],
            int(day), int(month), int(year), int(hours)
        ]], columns=['holiday', 'temp', 'rain', 'snow', 'weather', 'day', 'month', 'year', 'hours'])

        scaled_input = scaler.transform(input_data)
        predicted_volume = model.predict(scaled_input)[0]

        return render_template('result.html',
                               volume=int(predicted_volume),
                               ratio="N/A", origin="Manual Input", destination="Manual Input",
                               metrics=model_metrics, mode="Manual Input")
    except Exception as e:
        return render_template('interface.html', error=f"Error: {str(e)}", metrics=model_metrics)

if __name__ == "__main__":
    app.run(debug=True, port=5001)