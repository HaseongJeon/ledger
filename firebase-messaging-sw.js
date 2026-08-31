/* 브라우저(데스크톱 PWA)가 완전히 닫혀 있을 때도 알림을 띄우기 위한 서비스워커.
   오프라인 캐시용 sw.js 와는 별개 파일 — 둘은 서로 다른 스코프로 동시에 등록됩니다. */
importScripts("https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js");
importScripts("./config.js");

const fb = self.APP_CONFIG?.FIREBASE;
if (fb?.apiKey) {
  firebase.initializeApp({
    apiKey: fb.apiKey,
    authDomain: fb.authDomain,
    projectId: fb.projectId,
    messagingSenderId: fb.messagingSenderId,
    appId: fb.appId
  });
  const messaging = firebase.messaging();
  messaging.onBackgroundMessage(payload => {
    const { title, body } = payload.notification || {};
    if (title) self.registration.showNotification(title, { body });
  });
}
