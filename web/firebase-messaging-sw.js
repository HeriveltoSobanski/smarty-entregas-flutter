importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyC5B0vqDqq-sQ32W3gzvTKfXvWLl0z5MJw",
  authDomain: "smarty-entregas-c3415.firebaseapp.com",
  projectId: "smarty-entregas-c3415",
  storageBucket: "smarty-entregas-c3415.firebasestorage.app",
  messagingSenderId: "1088560191949",
  appId: "1:1088560191949:web:8824aea70ce64af3778c84",
  measurementId: "G-SFNNDY8R5Y",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  self.registration.showNotification(title ?? "Smarty Entregas", {
    body: body ?? "",
    icon: "/icons/Icon-192.png",
  });
});
