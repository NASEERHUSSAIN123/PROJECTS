# 🚀 Flodo Enterprise: Journey Task Manager

An advanced, full-stack task management engine featuring a **Video Game Journey Map UI**, recursive dependency logic, and enterprise-grade telemetry notifications.

Track : A and strech goals are all have been implemented. The project is built with a Python FastAPI backend and a Flutter frontend, designed for seamless task management and visualization.

---

## 🛠 Step-by-Step Installation

## 1️⃣ Frontend Setup (VS Code Method)

### Install VS Code

Download: <https://code.visualstudio.com/>

### Install Flutter Extension

* Open VS Code
* Press: `Ctrl + Shift + X`
* Search: **Flutter (Dart Code)**
* Click **Install**

### Automated SDK Setup

* Press: `Ctrl + Shift + P`
* Run: `Flutter: New Project`
* Select: **Download SDK**
* Recommended path:

```bash
C:\src\flutter
```

### Add Flutter to PATH

* Click **"Add SDK to Path"** when prompted

### Verify Installation

```bash
flutter doctor
```

✅ Only **Flutter** and **Chrome** need to be green ✔

---

## 2️⃣ Prioritize Chrome (Skip Android SDK)

Check available devices:

```bash
flutter devices
```

Expected:

```text
Chrome (web-javascript)
```

⚠️ Ignore Android errors in `flutter doctor`

---

## 3️⃣ Backend Setup (Python Workspace Engine)

### Install Python

<https://www.python.org/>

### Create Virtual Environment

```bash
cd backend
python -m venv venv
```

### Activate Virtual Environment

For Windows:

```bash
.\venv\Scripts\activate
```

For Mac/Linux:

```bash
source venv/bin/activate
```

### Install Dependencies

```bash
pip install -r requirements.txt
```

---

## 🚀 Execution Protocol

## Running the Application

⚠️ Run **Backend and Frontend simultaneously** in separate terminals

### Backend

1. Navigate to the backend directory:

```bash
cd backend
```

2. Activate the virtual environment:

For Windows:

```bash
.\venv\Scripts\activate
```

For Mac/Linux:

```bash
source venv/bin/activate
```

3. Run the server:

```bash
uvicorn main:app --reload
```

The server will start on <http://127.0.0.1:8000>

### Frontend

1. Navigate to the frontend directory:

```bash
cd frontend/task_app
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run the Flutter app:

```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

Select Chrome as the device.

---

## 🏗 Key Features

### 🎮 Workflow Cartography

* Visual S-curve task journey map
* RPG-style dependency tree

### ⏳ Cascade Time-Shift Engine

* Parent task updates automatically shift child tasks

### 🔒 Physical UI Locks

* Prevents selecting past time
* Greyed-out invalid inputs

### 🧬 Shadow Versioning

* Tracks task versions (v1, v2, v3)
* Stored in SQLite

### 📡 Professional Telemetry

* Enterprise-grade error handling
* Smart validation messages

---

## 📁 Project Structure

```text
/backend
  ├── main.py
  ├── models.py
  ├── tasks.db
  └── requirements.txt

/frontend
  └── task_app
       ├── lib/
       ├── widgets/
       └── journey_map/
```

---

## 🆘 Troubleshooting

### ❌ CORS / Data Not Saving

Ensure you used:

```bash
--disable-web-security
```

---

### ❌ Command Not Found

Restart system after Flutter install

---

### ❌ Backend Crash (Database Issue)

Delete DB:

```bash
rm backend/tasks.db
```

Restart backend:

```bash
uvicorn main:app --reload
```

---

## ⚡ Quick Run (All Commands Together)

## Terminal 1 (Backend)

```bash
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

## Terminal 2 (Frontend)

```bash
cd frontend/task_app
flutter pub get
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

---

## 💡 Pro Tip (Copy Commands Easily)

👉 Triple-click inside any code block to select all
👉 Or use:

* Windows: `Ctrl + C`
* Mac: `Cmd + C`

---

## ✅ You're Ready

Your **Flodo Enterprise Journey Task Manager** is now fully operational 🚀
