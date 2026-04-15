// ✅ FIX: Use the same version (10.7.1) and 'compat' libraries as index.html
importScripts(
  "https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js"
);

firebase.initializeApp({
  apiKey: "AIzaSyBBteJZoirarB77b3Cgo67njG6meoGNq_U",
  authDomain: "ascon-alumni-91df2.firebaseapp.com",
  projectId: "ascon-alumni-91df2",
  storageBucket: "ascon-alumni-91df2.firebasestorage.app",
  messagingSenderId: "826004672204",
  appId: "1:826004672204:web:4352aaeba03118fb68fc69",
});

const messaging = firebase.messaging();

// Optional: Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log(
    "[firebase-messaging-sw.js] Received background message ",
    payload
  );
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png",
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
