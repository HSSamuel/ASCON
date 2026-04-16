# ASCON Alumni Backend API

The **ASCON Alumni Backend** is a robust RESTful API built with **Node.js** and **Express.js**. It serves as the central brain for the ASCON Alumni platform, handling authentication, user management, event scheduling, smart matching, and highly scalable real-time communications (Chat & Voice Calls) for both the **Mobile App** and the **Web Admin Dashboard**.

---

## 🛠️ Tech Stack

- **Runtime:** Node.js  
- **Framework:** Express.js  
- **Database:** MongoDB (via Mongoose)  
- **Real-Time Communication:** Socket.io  
- **Horizontal Scaling:** Redis (`@socket.io/redis-adapter`)  
- **VoIP Calling:** Agora RTC (Token Generation & Signaling)  
- **Authentication:** JWT (Access & Refresh Tokens) + Google OAuth  
- **Notifications:** Firebase Cloud Messaging (FCM)  
- **Email Service:** Gmail API  
- **API Documentation:** Swagger UI  

---

## 🚀 Getting Started

### 1. Prerequisites

- Node.js (v16 or higher)  
- MongoDB (Local or Atlas)  
- Redis (Optional but recommended)  

---

### 2. Installation

```bash
cd backend
npm install
```

---

### 3. Environment Configuration

Create a `.env` file:

```env
PORT=5000
DB_CONNECT=mongodb+srv://<username>:<password>@cluster.mongodb.net/...

JWT_SECRET=your_access_secret
REFRESH_SECRET=your_refresh_secret

GOOGLE_CLIENT_ID=your_google_client_id

USE_REDIS=true
REDIS_URL=redis://localhost:6379

AGORA_APP_ID=your_agora_app_id
AGORA_APP_CERTIFICATE=your_agora_certificate
```

---

### 4. Running the Server

**Development**
```bash
npx nodemon server.js
```

**Production**
```bash
npm start
```

---

## 📖 API Documentation

- Local: http://localhost:5000/api-docs  
- Live: https://ascon.onrender.com/api-docs  

---

## 📂 Project Structure

```plaintext
backend/
├── config/
├── controllers/
├── models/
├── routes/
├── services/
├── utils/
├── server.js
└── package.json
```

---

## 🔐 Key Features

- Real-time chat and presence system  
- Agora-powered voice calling with call logs  
- Secure JWT + Google OAuth authentication  
- Firebase push notifications  
- Role-Based Access Control (RBAC)  
- AI-lite alumni matching & unique Alumni IDs  

---

## ⚠️ Troubleshooting

- **503 Error:** Server cold start or MongoDB IP issue  
- **DB Connection Error:** Check `.env` and IP whitelist  
- **Missing Env Vars:** Server will crash on startup  

---

© ASCON Alumni Platform – Backend API
