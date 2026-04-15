# ASCON Alumni Admin Portal

The **ASCON Alumni Admin Portal** is a modern, responsive web dashboard built with **React.js**. It serves as the command center for ASCON staff, enabling them to manage alumni records, approve registrations, publish events, manage content, and verify digital identities in real time.

---

## 🛠️ Tech Stack

* **Framework:** React.js (Create React App)
* **Routing:** React Router DOM (v6)
* **State Management:** React Hooks (`useState`, `useEffect`, Custom Hooks)
* **HTTP Client:** Axios
* **Styling:** CSS Modules & Responsive Grid Layouts
* **Icons:** React Icons
* **Deployment:** Netlify (Static Site)

---

## 🚀 Getting Started

### 1. Prerequisites

Ensure you have the following installed:

* [Node.js](https://nodejs.org/) (v16 or higher)
* **Backend API:** The ASCON Alumni Backend API must be running (locally or deployed on Render)

---

### 2. Installation

Navigate to the admin dashboard directory and install dependencies:

```bash
cd ascon_web_admin
npm install
```

---

### 3. Environment Configuration

Create a `.env` file in the root of the **ascon_web_admin** folder to connect the frontend to the backend API:

```env
# ------------------------------
# 🔗 API CONNECTION
# ------------------------------

# Option A: Local Development
REACT_APP_API_URL=http://localhost:5000

# Option B: Live Production (Render)
# REACT_APP_API_URL=https://ascon.onrender.com
```

> **Note:** React requires all environment variables to start with `REACT_APP_`.

---

### 4. Running the Dashboard

#### Development Mode

Runs the application in development mode. Open **[http://localhost:3000](http://localhost:3000)** in your browser.

```bash
npm start
```

#### Production Build

Builds the app for production into the `build` folder.

```bash
npm run build
```

---

## 📂 Project Structure

```plaintext
ascon_web_admin/
├── public/
│   ├── _redirects        # Netlify routing configuration
│   └── index.html        # HTML entry point
├── src/
│   ├── assets/           # Images and static files
│   ├── components/       # Reusable UI components (NavBar, StatCard, Modals)
│   ├── hooks/            # Custom hooks (useAuth, useStats, usePaginatedFetch)
│   ├── pages/            # Main views (UsersManager, EventsManager)
│   ├── App.js            # Route definitions
│   └── index.js          # React entry point
└── package.json          # Dependencies and scripts
```

---

## 🔐 Key Features

### 1. Dashboard Overview

* Real-time statistics for:

  * Total Users
  * Active Events
  * Pending Registrations
* Visual summaries and analytics of alumni data

---

### 2. User Management (`UsersManager.js`)

* **Search & Filter:** Locate alumni by name, email, or Alumni ID
* **Verification Control:** Approve or revoke alumni verification status
* **Role Management:** Promote users to **Admin** or **Editor** roles
* **Security Controls:**

  * "View Only" admins cannot delete or modify sensitive data

---

### 3. Content Management

* **Events & News:** Create, edit, and delete events pushed to the mobile app
* **Programmes:** Manage academic programmes and course details
* **Jobs:** Post and manage career opportunities for alumni

---

### 4. Digital ID Verification (`VerificationPage.jsx`)

* **Public Route:** Accessible without login at `/verify/:id`
* **QR Code Support:**

  * Scanning an alumni ID card QR code validates the ID against the backend
  * Instantly displays **Valid** or **Invalid** status
* Designed for use by security personnel and external verifiers

---

## 🌍 Deployment (Netlify)

This project is pre-configured for deployment on **Netlify**.

### The `_redirects` File

Because this is a **Single Page Application (SPA)** using client-side routing, a `_redirects` file is included in the `public` folder:

```plaintext
/* /index.html  200
```

This ensures that refreshing routes (e.g., `/users`) does not result in a 404 error on the live site.

---

### Deployment Steps

1. Connect your GitHub repository to **Netlify**
2. Set the **Build Command** to:

   ```bash
   npm run build
   ```
3. Set the **Publish Directory** to:

   ```plaintext
   build
   ```
4. Add `REACT_APP_API_URL` under **Netlify → Environment Variables**

---

**© ASCON Alumni Platform – Admin Portal**
