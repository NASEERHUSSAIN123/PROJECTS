from flask import Flask, request, render_template, jsonify, redirect, url_for
import random
import smtplib
from email.mime.text import MIMEText
import os
from pymongo import MongoClient
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from xgboost import XGBRegressor
from sklearn.metrics import mean_absolute_error

app = Flask(__name__)

# MongoDB Configuration with Error Handling
try:
    client = MongoClient('mongodb://localhost:27017/')
    db = client['APSCHE']
    users_collection = db['userdata']
except Exception as e:
    print(f"Error connecting to MongoDB: {e}")

# OTP Storage
otp_store = {}

# Email Credentials
EMAIL_SENDER = "clginternshipacc@gmail.com"
EMAIL_PASSWORD = os.getenv("EMAIL_PASSWORD", "asrn pwxu jile azwt")  # Use env var in production

def send_email(email, otp):
    subject = "Your OTP Code"
    message = f"Your OTP code is {otp}. Use it to log in."

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
            return "All fields are required.", 400

        if password != confirm_password:
            return "Passwords do not match.", 400

        # Check if email already exists
        if users_collection.find_one({"email": email}):
            return "User already registered.", 400

        # Insert user into MongoDB
        users_collection.insert_one({
            "first_name": fname,
            "last_name": lname,
            "email": email,
            "password": password
        })

        return redirect(url_for('index'))

    return render_template('register.html')

@app.route('/send-otp', methods=['POST'])
def send_otp():
    data = request.json
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({"message": "Email and password are required"}), 400

    # Validate user credentials
    user = users_collection.find_one({"email": email, "password": password})
    if not user:
        return jsonify({"message": "Invalid email or password"}), 401

    # Generate OTP
    otp = random.randint(100000, 999999)
    otp_store[email] = otp

    if send_email(email, otp):
        return jsonify({"message": f"OTP sent to {email}"}), 200
    else:
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

@app.route('/interface')
def interface():
    return render_template('interface.html')

# Load dataset
data = pd.read_csv(r"D:\Internship APSCHE\traffic volume.csv")

# Encode 'weather' column
weather_encoder = LabelEncoder()
data['weather'] = weather_encoder.fit_transform(data['weather'].fillna('Clouds'))

# Define features and target
features = ['holiday', 'temp', 'rain', 'snow', 'weather', 'day', 'month', 'year', 'hours', 'minutes', 'seconds']
target = 'traffic_volume'

X = data[features]
y = data[target]

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

# Feature scaling
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Train XGBRegressor
model = XGBRegressor(objective='reg:squarederror', random_state=42)
model.fit(X_train_scaled, y_train)

@app.route('/process', methods=['POST'])
def process():
    try:
        # Parse form inputs
        holiday = request.form.get('holiday', "").strip()
        temp = request.form.get('temp', "").strip()
        rain = request.form.get('rain', "").strip()
        snow = request.form.get('snow', "").strip()
        weather = request.form.get('weather', "").strip()
        day = request.form.get('day', "").strip()
        month = request.form.get('month', "").strip()
        year = request.form.get('year', "").strip()
        hours = request.form.get('hours', "").strip()
        minutes = request.form.get('minutes', "").strip()
        seconds = request.form.get('seconds', "").strip()

        # Validate all fields
        fields = [holiday, temp, rain, snow, weather, day, month, year, hours, minutes, seconds]
        if not all(fields):
            return jsonify({"error": "All fields must be provided."}), 400

        # Convert types
        input_data = pd.DataFrame([[
            int(holiday),
            float(temp),
            float(rain),
            float(snow),
            weather_encoder.transform([weather])[0],
            int(day),
            int(month),
            int(year),
            int(hours),
            int(minutes),
            int(seconds)
        ]], columns=[
            'holiday', 'temp', 'rain', 'snow', 'weather',
            'day', 'month', 'year', 'hours', 'minutes', 'seconds'
        ])

        # Scale
        input_scaled = scaler.transform(input_data)

        # Predict
        predicted_volume = model.predict(input_scaled)[0]

        # Render result page
        return render_template('result.html',
                               predicted_volume=round(predicted_volume, 2),
                               inputs={
                                   'Holiday': holiday,
                                   'Temp (K)': temp,
                                   'Rain (mm)': rain,
                                   'Snow (mm)': snow,
                                   'Weather': weather,
                                   'Date': f"{day}/{month}/{year}",
                                   'Time': f"{hours}:{minutes}:{seconds}"
                               })

    except Exception as e:
        return jsonify({"error": f"Processing error: {str(e)}"}), 500


if __name__ == "__main__":
    app.run(debug=True, port=5001)
