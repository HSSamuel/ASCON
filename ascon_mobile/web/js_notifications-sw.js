// ascon_mobile/web/js_notifications-sw.js

self.addEventListener("install", (event) => {
  // Force this service worker to become the active service worker
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  // Claim any clients immediately, so they can be controlled by this service worker
  event.waitUntil(self.clients.claim());
});

self.addEventListener("push", (event) => {
  // Placeholder for push notifications
  console.log("[js_notifications-sw] Push Received:", event);
});

self.addEventListener("notificationclick", (event) => {
  console.log("[js_notifications-sw] Notification Clicked", event);
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window" }).then((clientList) => {
      if (clientList.length > 0) {
        clientList[0].focus();
      }
    }),
  );
});
