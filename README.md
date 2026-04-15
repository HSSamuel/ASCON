# ASCON Alumni Association Platform

**ASCON Alumni** is the official digital platform for the Administrative Staff College of Nigeria (ASCON) Alumni. It bridges the gap between the institution and its graduates, providing Digital Identity, Networking, Smart Career Matching, Real-Time Voice/Group Calling, and Verification services.

## 🚀 Project Architecture

The project is a **Full-Stack Application** divided into three distinct parts:

| Folder                 | Tech Stack            | Description                                                                                                   |
| :--------------------- | :-------------------- | :------------------------------------------------------------------------------------------------------------ |
| **`/ascon_mobile`**    | **Flutter (Dart)**    | The Android/iOS mobile app used by Alumni. Features Digital ID, Smart Match, Voice Calls, and Real-Time Chat. |
| **`/ascon_web_admin`** | **React.js**          | The Admin Portal for ASCON staff to Approve users, Post Events, and Verify IDs.                               |
| **`/backend`**         | **Node.js & Express** | The central API connecting the App, Website, and MongoDB Database.                                            |

---

## 🛠️ Setup Instructions

### 1. Backend API (The Brain)

_Located in `/backend`_

1.  Navigate to the folder: `cd backend`
2.  Install dependencies: `npm install`
3.  **Environment Variables:** Create a `.env` file in the `backend` folder with these keys:

    ```env
    # Database & Server
    DB_CONNECT = mongodb+srv://YOUR_MONGO_URL
    PORT = 5000

    # Security Secrets
    JWT_SECRET = your_super_secret_access_key
    REFRESH_SECRET = your_super_secret_refresh_key

    # Email Service (Gmail API) https://developers.google.com/oauthplayground
    MAILER_CLIENT_ID=
    MAILER_CLIENT_SECRET=
    MAILER_REFRESH_TOKEN=

    # Google Auth
    GOOGLE_CLIENT_ID = your_google_client_id

    # Redis (For Scalable Sockets)
    USE_REDIS = true
    REDIS_URL = redis://localhost:6379

    # Agora RTC (For Voice Calling)
    AGORA_APP_ID = your_agora_app_id_here
    AGORA_APP_CERTIFICATE = your_agora_certificate_here
    ```

4.  Start the server: `npm start`
5.  _Server runs on: `http://localhost:5000`_

### 2. Admin Portal (The Dashboard)

_Located in `/ascon_web_admin`_

1.  Navigate to the folder: `cd ascon_web_admin`
2.  Install dependencies: `npm install`
3.  **Configuration:** Ensure `.env` points to your backend:
    ```env
    REACT_APP_API_URL=http://localhost:5000
    # For Production: REACT_APP_API_URL=[https://ascon.onrender.com]
    ```
4.  Start the dashboard: `npm start`
5.  _Access at: `http://localhost:3000`_

### 3. Mobile App (The Client)

_Located in `/ascon_mobile`_

1.  Navigate to the folder: `cd ascon_mobile`
2.  Install packages: `flutter pub get`
3.  **Environment Configuration:**
    Create an `env.txt` file in the root of `ascon_mobile` to switch between Local and Production servers easily.

    ```env
    # API Connection (Use your computer's IP address for local testing on Physical devices)
    API_URL=[http://192.168.1.xxx:5000](http://192.168.1.xxx:5000)
    # For Production: API_URL=[https://ascon.onrender.com]

    # Firebase Cloud Messaging (Web Push Key)
    FIREBASE_VAPID_KEY=your_firebase_vapid_key

    # Agora RTC App ID
    AGORA_APP_ID=your_agora_app_id_here
    ```

4.  **Run the app:** - Development: `flutter run`
    - Web (CORS Disabled): `flutter run -d chrome --web-browser-flag "--disable-web-security"`
5.  **Build Release (Android - Optimized Size):** `flutter build apk --split-per-abi` _(Distribute the `arm64-v8a` version to reduce APK size from ~278MB to ~120MB)_
6.  **Build Release (iPhone):** `flutter build ios --release`
7.  **Build Web Version:** `flutter build web`
8.  **Deploy to Netlify:** `netlify deploy --prod --dir=build/web`

---

## 🔐 Key Features

### 1. Auto-Generated Digital ID

- **Logic:** Upon registration, every user is assigned a unique Alumni ID (e.g., `ASC/2025/0042`).
- **Visual:** The mobile app renders a realistic ID card with a QR Code.
- **Verification:** The QR Code links to a public `/verify/ASC-...` portal, allowing security personnel to validate identity instantly without logging in.

### 2. Real-Time Voice & Group Calling (Agora)

- **VoIP Engine:** Seamless 1-on-1 and Group voice calls powered by Agora RTC.
- **Iterative Group Ringing:** Implements a scalable signaling loop allowing an entire group to ring simultaneously without bogging down the Node.js server.
- **Call History:** Synchronized MongoDB call logs with automatic UI grouping for consecutive missed, dialed, and received calls.

### 3. WhatsApp-Style Real-time Chat (Socket.io + Redis)

- **Live Sync:** Features instantaneous message delivery, real-time typing indicators (`...`), and live read receipts (Grey/Blue ticks).
- **Multi-Server Scaling:** Integrated with `@socket.io/redis-adapter` allowing the chat and presence system to scale across multiple server instances.
- **"Double-Tap" Connection:** Emits online status instantly upon HTTP Login success, bypassing UI transition delays.

### 4. AI-Lite Smart Match System

- **Aggregation Pipeline:** Uses highly optimized MongoDB Aggregation pipelines to calculate matching scores between Alumni without overloading the server.
- **Weighted Scoring:** Users are matched based on Industry (10pts), Shared Skills (2pts per skill), and Class Year/Programme (1pt).

### 5. "Near Me" Geolocation System

- **Privacy First:** Alumni must explicitly toggle "Make Location Visible" in their profile to appear on the map.
- **Travel Mode:** Allows users to manually type a city (e.g., "Abuja") to find local alumni before traveling.
- **Security:** Queries are sanitized to prevent ReDoS attacks.

### 6. Smart Notification System (FCM)

- **Hybrid Support:** Works for both Android (Push Notifications) and Web.
- **"Cap & Slice" Strategy:** Each user account stores up to 5 active device tokens. When a 6th device logs in, the oldest token is automatically removed to prevent database bloat.

### 7. Role-Based Access Control (RBAC) & Mentorship

- **Super Admin:** Manage other admins and edit sensitive data.
- **Admin:** Approve users, post events, manage jobs.
- **Mentor (New):** Alumni can toggle "Open to Mentorship", earning a Gold Badge on their profile.
- **Security:** Protected via JWT Access Tokens (2h expiry) and Refresh Tokens (30d expiry).

---

## 📦 Deployment Status

- **Backend:** Deployed on **Render** (Node.js Web Service).
  - _Note: Free tier spins down after 15 mins. First request may take 60s._
- **Admin Panel:** Deployed on **Netlify** (React Static Site).
- **Database:** Hosted on **MongoDB Atlas**.
- **Mobile App:** Built as Split APKs (`arm64-v8a`) for Android distribution.

---

## 🤝 Contribution

Developed by **[HUNSA S. Samuel]** for the Administrative Staff College of Nigeria (ASCON).
