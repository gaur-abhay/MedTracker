const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// Listens for a new document in /triggers collection
// and sends an FCM push to the target user's device
exports.relayGuardianTrigger = onDocumentCreated("triggers/{docId}", async (event) => {
  const data = event.data.data();
  const { targetUserId, type } = data;

  if (type !== "guardian_trigger") return;

  // Look up the target user's FCM token
  const userDoc = await getFirestore().collection("users").doc(targetUserId).get();
  if (!userDoc.exists) {
    console.log(`User ${targetUserId} not found`);
    return;
  }

  const { fcmToken } = userDoc.data();
  if (!fcmToken) {
    console.log(`No FCM token for user ${targetUserId}`);
    return;
  }

  // Send FCM data message — app handles showing the alarm
  await getMessaging().send({
    token: fcmToken,
    data: { type: "guardian_trigger" },
    android: {
      priority: "high",
    },
  });

  console.log(`Guardian trigger sent to ${targetUserId}`);
});
