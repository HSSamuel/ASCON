// Import Firebase v9 compat scripts
importScripts(
  "https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js",
);

// Initialize Firebase App
firebase.initializeApp({
  apiKey: "AIzaSyBBteJZoirarB77b3Cgo67njG6meoGNq_U",
  authDomain: "ascon-alumni-91df2.firebaseapp.com",
  projectId: "ascon-alumni-91df2",
  storageBucket: "ascon-alumni-91df2.firebasestorage.app",
  messagingSenderId: "826004672204",
  appId: "1:826004672204:web:4352aaeba03118fb68fc69",
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log(
    "[firebase-messaging-sw.js] Received background message ",
    payload,
  );

  const notificationTitle =
    payload.notification?.title || payload.data?.title || "ASCON Alumni Update";
  const notificationOptions = {
    body:
      payload.notification?.body ||
      payload.data?.body ||
      "You have a new notification.",
    icon: "/icons/Icon-192.png", // Ensure this icon exists in your web/icons folder
    data: payload.data,
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions,
  );
});

// Handle notification clicks to focus the tab or open a new one
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const route = event.notification.data?.route || "home";

  event.waitUntil(
    clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((windowClients) => {
        // Check if there is already a window/tab open with the target URL
        for (let i = 0; i < windowClients.length; i++) {
          const client = windowClients[i];
          if (
            client.url.includes(self.registration.scope) &&
            "focus" in client
          ) {
            return client.focus();
          }
        }
        // If no window is open, open a new one
        if (clients.openWindow) {
          return clients.openWindow(self.registration.scope + route);
        }
      }),
  );
});
