/**
 * Firebase Cloud Functions for Library Management System
 *
 * This module contains scheduled and triggered cloud functions for:
 * - Checking overdue loans and calculating fines
 * - Sending push notifications to users
 * - Managing loan status updates
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Get Firestore reference
const db = admin.firestore();

// Set global options for all functions
setGlobalOptions({
  maxInstances: 10,
  region: "us-central1",
  timeoutSeconds: 540,
  memory: "256MiB",
});

// Configuration constants
const FINE_PER_DAY = 1.0; // $1.00 per day overdue
const BATCH_SIZE = 100; // Process loans in batches to avoid timeouts

/**
 * Scheduled function that runs daily to check for overdue loans
 *
 * Schedule: Runs every day at midnight UTC (0 0 * * *)
 *
 * Process:
 * 1. Query all loans with status "borrowed" and dueDate < now
 * 2. Calculate fine for each overdue loan
 * 3. Update loan status to "overdue" and set fine amount
 * 4. Create notification documents
 * 5. Send FCM push notifications to users
 *
 * @function overdueChecker
 */
exports.overdueChecker = onSchedule(
    {
      schedule: "0 0 * * *", // Daily at midnight UTC
      timeZone: "UTC",
      retryConfig: {
        retryCount: 3,
        minBackoffDuration: "60s",
        maxBackoffDuration: "600s",
      },
    },
    async (event) => {
      logger.info("Starting overdue loan checker...");

      try {
        const now = admin.firestore.Timestamp.now();
        const startTime = Date.now();

        // Query all borrowed loans that are past due
        const overdueLoansSnapshot = await db
            .collection("loans")
            .where("status", "==", "borrowed")
            .where("dueDate", "<", now)
            .get();

        if (overdueLoansSnapshot.empty) {
          logger.info("No overdue loans found");
          return {success: true, processedCount: 0};
        }

        logger.info(`Found ${overdueLoansSnapshot.size} overdue loans`);

        // Process loans in batches
        const loans = overdueLoansSnapshot.docs;
        let processedCount = 0;
        let errorCount = 0;

        for (let i = 0; i < loans.length; i += BATCH_SIZE) {
          const batch = loans.slice(i, i + BATCH_SIZE);
          try {
            const result = await processOverdueBatch(batch, now);
            processedCount += result.processed;
            errorCount += result.errors;
          } catch (error) {
            logger.error(`Error processing batch ${i / BATCH_SIZE}:`, error);
            errorCount += batch.length;
          }
        }

        const duration = Date.now() - startTime;
        logger.info(
            `Overdue checker completed in ${duration}ms. ` +
          `Processed: ${processedCount}, Errors: ${errorCount}`,
        );

        return {
          success: true,
          processedCount,
          errorCount,
          totalLoans: loans.length,
          durationMs: duration,
        };
      } catch (error) {
        logger.error("Fatal error in overdueChecker:", error);
        throw error;
      }
    },
);

/**
 * Process a batch of overdue loans
 *
 * @param {Array} loanDocs - Array of loan documents
 * @param {admin.firestore.Timestamp} now - Current timestamp
 * @return {Object} Result with processed and error counts
 */
async function processOverdueBatch(loanDocs, now) {
  const batch = db.batch();
  const notifications = [];

  let processed = 0;
  let errors = 0;

  for (const loanDoc of loanDocs) {
    try {
      const loan = loanDoc.data();
      const loanRef = loanDoc.ref;

      // Calculate days overdue
      const dueDateMillis = loan.dueDate.toMillis();
      const nowMillis = now.toMillis();
      const daysOverdue = Math.ceil(
          (nowMillis - dueDateMillis) / (1000 * 60 * 60 * 24),
      );

      // Calculate fine
      const fine = daysOverdue * FINE_PER_DAY;

      // Update loan document
      batch.update(loanRef, {
        status: "overdue",
        fine: fine,
        daysOverdue: daysOverdue,
        lastChecked: now,
        overdueNotifiedAt: now,
      });

      // Prepare notification data
      notifications.push({
        userId: loan.userId,
        bookId: loan.bookId,
        loanId: loanDoc.id,
        daysOverdue: daysOverdue,
        fine: fine,
      });

      processed++;
    } catch (error) {
      logger.error(`Error processing loan ${loanDoc.id}:`, error);
      errors++;
    }
  }

  // Commit the batch update
  if (processed > 0) {
    await batch.commit();
    logger.info(`Batch committed: ${processed} loans updated`);

    // Create notification documents and send FCM messages
    await createNotifications(notifications);
    await sendPushNotifications(notifications);
  }

  return {processed, errors};
}

/**
 * Create notification documents in Firestore
 *
 * @param {Array} notifications - Array of notification data
 */
async function createNotifications(notifications) {
  if (notifications.length === 0) return;

  try {
    const notificationBatch = db.batch();

    for (const notif of notifications) {
      // Get book details for notification message
      let bookTitle = "your book";
      try {
        const bookDoc = await db.collection("books").doc(notif.bookId).get();
        if (bookDoc.exists) {
          bookTitle = bookDoc.data().title;
        }
      } catch (error) {
        logger.warn(`Could not fetch book title for ${notif.bookId}:`, error);
      }

      // Create notification document
      const notificationRef = db.collection("notifications").doc();
      notificationBatch.set(notificationRef, {
        userId: notif.userId,
        type: "overdue",
        title: "Book Overdue",
        message:
          `${bookTitle} is ${notif.daysOverdue} day(s) overdue. ` +
          `Fine: $${notif.fine.toFixed(2)}. Please return it soon.`,
        data: {
          loanId: notif.loanId,
          bookId: notif.bookId,
          daysOverdue: notif.daysOverdue,
          fine: notif.fine,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await notificationBatch.commit();
    logger.info(`Created ${notifications.length} notification documents`);
  } catch (error) {
    logger.error("Error creating notifications:", error);
    throw error;
  }
}

/**
 * Send FCM push notifications to users
 *
 * @param {Array} notifications - Array of notification data
 */
async function sendPushNotifications(notifications) {
  if (notifications.length === 0) return;

  try {
    const messaging = admin.messaging();
    const messagePromises = [];

    for (const notif of notifications) {
      try {
        // Get user's FCM tokens
        const userDoc = await db.collection("users").doc(notif.userId).get();

        if (!userDoc.exists) {
          logger.warn(`User ${notif.userId} not found`);
          continue;
        }

        const userData = userDoc.data();
        const fcmTokens = userData.fcmTokens || [];

        if (fcmTokens.length === 0) {
          logger.info(`No FCM tokens for user ${notif.userId}`);
          continue;
        }

        // Get book title for notification
        let bookTitle = "Book";
        try {
          const bookDoc = await db.collection("books").doc(notif.bookId).get();
          if (bookDoc.exists) {
            bookTitle = bookDoc.data().title;
          }
        } catch (error) {
          logger.warn(`Could not fetch book title: ${error.message}`);
        }

        // Create FCM message
        const message = {
          notification: {
            title: "Book Overdue!",
            body:
              `${bookTitle} is ${notif.daysOverdue} days overdue. ` +
              `Fine: $${notif.fine.toFixed(2)}`,
          },
          data: {
            type: "overdue",
            loanId: notif.loanId,
            bookId: notif.bookId,
            daysOverdue: notif.daysOverdue.toString(),
            fine: notif.fine.toString(),
          },
          tokens: fcmTokens,
        };

        // Send to all user's devices
        messagePromises.push(
            messaging
                .sendEachForMulticast(message)
                .then((response) => {
                  logger.info(
                      `Sent notification to user ${notif.userId}: ` +
                  `${response.successCount} success, ` +
                  `${response.failureCount} failures`,
                  );

                  // Remove invalid tokens
                  if (response.failureCount > 0) {
                    const tokensToRemove = [];
                    response.responses.forEach((resp, idx) => {
                      if (!resp.success) {
                        const error = resp.error;
                        const invalidToken =
                      error.code === "messaging/invalid-registration-token";
                        const notRegistered =
                      error.code ===
                      "messaging/registration-token-not-registered";
                        if (invalidToken || notRegistered) {
                          tokensToRemove.push(fcmTokens[idx]);
                        }
                      }
                    });

                    // Remove invalid tokens from user document
                    if (tokensToRemove.length > 0) {
                      return db
                          .collection("users")
                          .doc(notif.userId)
                          .update({
                            fcmTokens: admin.firestore.FieldValue.arrayRemove(
                                ...tokensToRemove,
                            ),
                          });
                    }
                  }
                  return null;
                })
                .catch((error) => {
                  logger.error(`Error sending FCM to user ${notif.userId}:`, error);
                }),
        );
      } catch (error) {
        logger.error(`Error preparing FCM for user ${notif.userId}:`, error);
      }
    }

    // Wait for all messages to be sent
    await Promise.all(messagePromises);
    logger.info(
        `Processed FCM notifications for ${notifications.length} users`,
    );
  } catch (error) {
    logger.error("Error sending push notifications:", error);
    // Don't throw - notifications are not critical
  }
}

/**
 * Callable function to manually trigger overdue check
 *
 * This allows librarians to manually run the overdue checker
 * without waiting for the scheduled time.
 *
 * Requires authentication and librarian role.
 *
 * @function manualOverdueCheck
 */
exports.manualOverdueCheck = onCall(
    {
      enforceAppCheck: false,
    },
    async (request) => {
    // Verify authentication
      if (!request.auth) {
        throw new Error("Authentication required");
      }

      try {
      // Verify user is a librarian
        const userDoc = await db.collection("users").doc(request.auth.uid).get();

        if (!userDoc.exists) {
          throw new Error("User not found");
        }

        const userData = userDoc.data();
        if (userData.role !== "librarian") {
          throw new Error("Unauthorized: Librarian access required");
        }

        logger.info(`Manual overdue check triggered by user ${request.auth.uid}`);

        // Run the same logic as scheduled function
        const now = admin.firestore.Timestamp.now();
        const overdueLoansSnapshot = await db
            .collection("loans")
            .where("status", "==", "borrowed")
            .where("dueDate", "<", now)
            .get();

        if (overdueLoansSnapshot.empty) {
          return {
            success: true,
            message: "No overdue loans found",
            processedCount: 0,
          };
        }

        const loans = overdueLoansSnapshot.docs;
        let processedCount = 0;
        let errorCount = 0;

        for (let i = 0; i < loans.length; i += BATCH_SIZE) {
          const batch = loans.slice(i, i + BATCH_SIZE);
          const result = await processOverdueBatch(batch, now);
          processedCount += result.processed;
          errorCount += result.errors;
        }

        return {
          success: true,
          message: `Processed ${processedCount} overdue loans`,
          processedCount,
          errorCount,
          totalLoans: loans.length,
        };
      } catch (error) {
        logger.error("Error in manual overdue check:", error);
        throw new Error(`Failed to check overdue loans: ${error.message}`);
      }
    },
);

/**
 * Callable function to send a custom notification to a user
 *
 * This allows the app to send custom notifications through the backend.
 *
 * @function sendNotification
 */
exports.sendNotification = onCall(async (request) => {
  const {userId, title, body, data} = request.data;

  if (!userId || !title || !body) {
    throw new Error("Missing required parameters: userId, title, body");
  }

  try {
    // Get user's FCM tokens
    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists) {
      throw new Error("User not found");
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      logger.info(`No FCM tokens for user ${userId}`);
      return {success: false, message: "User has no registered devices"};
    }

    // Create notification document
    await db.collection("notifications").add({
      userId,
      type: (data && data.type) || "general",
      title,
      message: body,
      data: data || {},
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send FCM message
    const message = {
      notification: {title, body},
      data: data || {},
      tokens: fcmTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    logger.info(
        `Notification sent to user ${userId}: ` +
        `${response.successCount} success, ${response.failureCount} failures`,
    );

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    logger.error("Error sending notification:", error);
    throw new Error(`Failed to send notification: ${error.message}`);
  }
});
