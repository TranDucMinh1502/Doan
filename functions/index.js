const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Send notification when book item becomes available for reservation
exports.onBookItemAvailable = functions.firestore
  .document("bookItems/{itemId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Check if item status changed from 'loaned' to 'available'
    if (before.status === "loaned" && after.status === "available") {
      const bookId = after.bookId;

      // Get earliest waiting reservation
      const reservationsSnapshot = await admin
        .firestore()
        .collection("reservations")
        .where("bookId", "==", bookId)
        .where("status", "==", "waiting")
        .orderBy("reservedAt")
        .limit(1)
        .get();

      if (!reservationsSnapshot.empty) {
        const reservationDoc = reservationsSnapshot.docs[0];
        const reservation = reservationDoc.data();

        // Update reservation status
        await reservationDoc.ref.update({
          status: "ready",
          itemId: context.params.itemId,
          notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Get user's FCM tokens
        const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(reservation.userId)
          .get();

        if (userDoc.exists) {
          const user = userDoc.data();
          const tokens = user.fcmTokens || [];

          if (tokens.length > 0) {
            // Get book details
            const bookDoc = await admin
              .firestore()
              .collection("books")
              .doc(bookId)
              .get();
            const book = bookDoc.data();

            // Send notification
            const message = {
              notification: {
                title: "Reserved Book Ready! 📚",
                body: `"${book.title}" is now available for pickup`,
              },
              data: {
                type: "reservation_ready",
                bookId: bookId,
                reservationId: reservationDoc.id,
              },
              tokens: tokens,
            };

            try {
              const response = await admin.messaging().sendMulticast(message);
              console.log("Successfully sent message:", response);
            } catch (error) {
              console.log("Error sending message:", error);
            }
          }
        }
      }
    }
  });

// Check for overdue loans daily
exports.checkOverdueLoans = functions.pubsub
  .schedule("0 9 * * *") // Run daily at 9 AM
  .timeZone("Asia/Ho_Chi_Minh")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    // Get all issued loans that are overdue
    const loansSnapshot = await admin
      .firestore()
      .collection("loans")
      .where("status", "==", "issued")
      .where("dueDate", "<", now)
      .get();

    const notifications = [];

    for (const loanDoc of loansSnapshot.docs) {
      const loan = loanDoc.data();

      // Update loan status
      await loanDoc.ref.update({ status: "overdue" });

      // Get user's FCM tokens
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(loan.userId)
        .get();

      if (userDoc.exists) {
        const user = userDoc.data();
        const tokens = user.fcmTokens || [];

        if (tokens.length > 0) {
          // Get book details
          const bookDoc = await admin
            .firestore()
            .collection("books")
            .doc(loan.bookId)
            .get();
          const book = bookDoc.data();

          const daysOverdue = Math.ceil(
            (now.seconds - loan.dueDate.seconds) / 86400
          );

          notifications.push({
            notification: {
              title: "Overdue Book! ⚠️",
              body: `"${book.title}" is ${daysOverdue} day(s) overdue. Please return it soon.`,
            },
            data: {
              type: "overdue",
              loanId: loanDoc.id,
              bookId: loan.bookId,
              daysOverdue: daysOverdue.toString(),
            },
            tokens: tokens,
          });
        }
      }
    }

    // Send all notifications
    for (const message of notifications) {
      try {
        await admin.messaging().sendMulticast(message);
        console.log("Sent overdue notification");
      } catch (error) {
        console.log("Error sending notification:", error);
      }
    }

    return null;
  });

// Send reminder 2 days before due date
exports.sendDueReminders = functions.pubsub
  .schedule("0 9 * * *") // Run daily at 9 AM
  .timeZone("Asia/Ho_Chi_Minh")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const twoDaysFromNow = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 2 * 24 * 60 * 60 * 1000)
    );

    // Get loans due in 2 days
    const loansSnapshot = await admin
      .firestore()
      .collection("loans")
      .where("status", "==", "issued")
      .where("dueDate", ">=", now)
      .where("dueDate", "<=", twoDaysFromNow)
      .get();

    for (const loanDoc of loansSnapshot.docs) {
      const loan = loanDoc.data();

      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(loan.userId)
        .get();

      if (userDoc.exists) {
        const user = userDoc.data();
        const tokens = user.fcmTokens || [];

        if (tokens.length > 0) {
          const bookDoc = await admin
            .firestore()
            .collection("books")
            .doc(loan.bookId)
            .get();
          const book = bookDoc.data();

          const message = {
            notification: {
              title: "Book Due Soon 📅",
              body: `"${book.title}" is due in 2 days. Remember to return or renew it.`,
            },
            data: {
              type: "due_reminder",
              loanId: loanDoc.id,
              bookId: loan.bookId,
            },
            tokens: tokens,
          };

          try {
            await admin.messaging().sendMulticast(message);
            console.log("Sent due reminder");
          } catch (error) {
            console.log("Error sending reminder:", error);
          }
        }
      }
    }

    return null;
  });
