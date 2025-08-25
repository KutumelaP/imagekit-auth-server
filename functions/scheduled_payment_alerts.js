const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Run daily at 9 AM to check for overdue payments
exports.dailyPaymentAlerts = functions.pubsub.schedule('0 9 * * *')
  .timeZone('Africa/Johannesburg')
  .onRun(async (context) => {
    console.log('Running daily payment alerts check...');
    
    try {
      const db = admin.firestore();
      const now = new Date();
      const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
      const sevenDaysAgo = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
      
      // Get all platform receivables
      const receivablesSnap = await db.collection('platform_receivables').get();
      
      const overdueReminders = [];
      const criticalAlerts = [];
      
      for (const doc of receivablesSnap.docs) {
        const data = doc.data();
        const amount = (data.amount || 0);
        const lastUpdated = data.lastUpdated?.toDate() || new Date(0);
        const sellerId = doc.id;
        
        if (amount <= 0) continue; // Skip if no debt
        
        // Critical: Over 30 days and > R500
        if (lastUpdated < thirtyDaysAgo && amount > 500) {
          criticalAlerts.push({
            sellerId,
            amount,
            daysPastDue: Math.floor((now - lastUpdated) / (24 * 60 * 60 * 1000)),
            type: 'critical'
          });
        }
        // Warning: Over 7 days
        else if (lastUpdated < sevenDaysAgo && amount > 100) {
          overdueReminders.push({
            sellerId,
            amount,
            daysPastDue: Math.floor((now - lastUpdated) / (24 * 60 * 60 * 1000)),
            type: 'warning'
          });
        }
      }
      
      // Send seller notifications
      const batch = db.batch();
      
      // Process overdue reminders
      for (const alert of overdueReminders) {
        const notificationRef = db.collection('notifications').doc();
        batch.set(notificationRef, {
          userId: alert.sellerId,
          title: 'Payment Reminder',
          body: `You have outstanding fees of R${alert.amount.toFixed(2)} that are ${alert.daysPastDue} days overdue. Please settle your account to maintain COD access.`,
          type: 'payment_reminder',
          priority: 'normal',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
          metadata: {
            amount: alert.amount,
            daysPastDue: alert.daysPastDue
          }
        });
      }
      
      // Process critical alerts
      for (const alert of criticalAlerts) {
        const notificationRef = db.collection('notifications').doc();
        batch.set(notificationRef, {
          userId: alert.sellerId,
          title: 'URGENT: Payment Required',
          body: `URGENT: You have R${alert.amount.toFixed(2)} in outstanding fees that are ${alert.daysPastDue} days overdue. Your account may be suspended if not resolved within 48 hours.`,
          type: 'payment_critical',
          priority: 'high',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
          metadata: {
            amount: alert.amount,
            daysPastDue: alert.daysPastDue
          }
        });
        
        // Disable COD for critical cases
        await db.collection('users').doc(alert.sellerId).update({
          codDisabled: true,
          codDisabledReason: `Outstanding fees R${alert.amount.toFixed(2)} - ${alert.daysPastDue} days overdue`,
          codDisabledAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
      
      await batch.commit();
      
      // Send admin summary
      if (overdueReminders.length > 0 || criticalAlerts.length > 0) {
        const adminNotificationRef = db.collection('admin_notifications').doc();
        await adminNotificationRef.set({
          title: 'Daily Payment Alert Summary',
          body: `${overdueReminders.length} overdue reminders sent, ${criticalAlerts.length} critical alerts processed.`,
          type: 'payment_summary',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
          metadata: {
            overdueCount: overdueReminders.length,
            criticalCount: criticalAlerts.length,
            totalOverdueAmount: [...overdueReminders, ...criticalAlerts].reduce((sum, alert) => sum + alert.amount, 0)
          }
        });
      }
      
      console.log(`Payment alerts processed: ${overdueReminders.length} overdue, ${criticalAlerts.length} critical`);
      
    } catch (error) {
      console.error('Error in daily payment alerts:', error);
      
      // Send error notification to admin
      await admin.firestore().collection('admin_notifications').add({
        title: 'Payment Alerts System Error',
        body: `Error processing daily payment alerts: ${error.message}`,
        type: 'system_error',
        priority: 'high',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
    }
  });

// Weekly summary report (Sundays at 8 AM)
exports.weeklyPaymentSummary = functions.pubsub.schedule('0 8 * * 0')
  .timeZone('Africa/Johannesburg')
  .onRun(async (context) => {
    console.log('Running weekly payment summary...');
    
    try {
      const db = admin.firestore();
      
      // Get all platform receivables
      const receivablesSnap = await db.collection('platform_receivables').get();
      
      let totalOutstanding = 0;
      let sellersWithDebt = 0;
      const agingBuckets = {
        current: { count: 0, amount: 0 }, // 0-7 days
        overdue: { count: 0, amount: 0 }, // 8-30 days
        critical: { count: 0, amount: 0 } // 30+ days
      };
      
      const now = new Date();
      
      for (const doc of receivablesSnap.docs) {
        const data = doc.data();
        const amount = (data.amount || 0);
        const lastUpdated = data.lastUpdated?.toDate() || new Date(0);
        
        if (amount <= 0) continue;
        
        totalOutstanding += amount;
        sellersWithDebt++;
        
        const daysPastDue = Math.floor((now - lastUpdated) / (24 * 60 * 60 * 1000));
        
        if (daysPastDue <= 7) {
          agingBuckets.current.count++;
          agingBuckets.current.amount += amount;
        } else if (daysPastDue <= 30) {
          agingBuckets.overdue.count++;
          agingBuckets.overdue.amount += amount;
        } else {
          agingBuckets.critical.count++;
          agingBuckets.critical.amount += amount;
        }
      }
      
      // Create weekly summary
      await db.collection('admin_reports').add({
        type: 'weekly_payment_summary',
        reportDate: admin.firestore.FieldValue.serverTimestamp(),
        summary: {
          totalOutstanding: totalOutstanding,
          sellersWithDebt: sellersWithDebt,
          agingAnalysis: agingBuckets,
          collectionRate: receivablesSnap.docs.length > 0 ? 
            ((receivablesSnap.docs.length - sellersWithDebt) / receivablesSnap.docs.length) : 1
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Send admin notification
      await db.collection('admin_notifications').add({
        title: 'Weekly Payment Summary',
        body: `Weekly Report: R${totalOutstanding.toFixed(2)} outstanding from ${sellersWithDebt} sellers. ${agingBuckets.critical.count} accounts require urgent attention.`,
        type: 'weekly_summary',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        metadata: {
          totalOutstanding,
          sellersWithDebt,
          criticalAccounts: agingBuckets.critical.count
        }
      });
      
      console.log(`Weekly summary generated: R${totalOutstanding.toFixed(2)} from ${sellersWithDebt} sellers`);
      
    } catch (error) {
      console.error('Error in weekly payment summary:', error);
    }
  });
