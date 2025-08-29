# 🧹 Data Cleanup Guide

This guide provides comprehensive instructions for cleaning up orphaned data in your marketplace application using the built-in cleanup tools.

## 📋 Table of Contents

- [Overview](#overview)
- [Types of Orphaned Data](#types-of-orphaned-data)
- [Cleanup Methods](#cleanup-methods)
- [Admin Dashboard Cleanup](#admin-dashboard-cleanup)
- [Server-Side Script Cleanup](#server-side-script-cleanup)
- [Flutter App Cleanup](#flutter-app-cleanup)
- [Safety Measures](#safety-measures)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

Orphaned data refers to database records that reference entities (users, products, chats, etc.) that no longer exist. This commonly happens when:

- Users are deleted but their associated data remains
- Products are removed but reviews/orders remain
- Chat participants are deleted but conversations persist
- Notification recipients no longer exist

This guide provides tools to identify and clean up such orphaned data automatically.

## 📊 Types of Orphaned Data

### 1. **Chat Data**
- **Chats**: Conversations where buyer or seller no longer exists
- **Chat Messages**: Messages in orphaned chats
- **Chat Images**: Images uploaded to orphaned chats

### 2. **User-Related Data**
- **Notifications**: Notifications for deleted users
- **FCM Tokens**: Push notification tokens for deleted users
- **Chatbot Conversations**: Bot conversations for deleted users

### 3. **Product-Related Data**
- **Reviews**: Reviews for deleted products or by deleted users
- **Orders**: Orders referencing deleted users or products
- **Product Images**: Images for deleted products

### 4. **Media Files**
- **Profile Images**: Images for deleted user profiles
- **Store Images**: Images for deleted store accounts
- **Uncategorized Media**: Files not following naming conventions

## 🛠️ Cleanup Methods

### Method 1: Admin Dashboard (Recommended)

The admin dashboard provides a user-friendly interface for data cleanup with built-in safety measures.

**Features:**
- Visual interface with confirmation dialogs
- Real-time progress tracking
- Detailed reports of what was cleaned
- Separate tabs for data and image cleanup

### Method 2: Server-Side Script

For advanced users or automated cleanup, use the Node.js script for batch operations.

**Features:**
- Command-line interface
- Dry-run mode for safety
- Detailed logging
- Batch processing for large datasets

### Method 3: Flutter App Service

Direct integration in the Flutter app for programmatic cleanup.

**Features:**
- Programmatic access
- Real-time processing
- Mobile/desktop compatibility

## 🖥️ Admin Dashboard Cleanup

### Accessing Cleanup Tools

1. **Login to Admin Dashboard**
   ```
   Navigate to your admin dashboard
   Login with admin credentials
   ```

2. **Navigate to Cleanup Tools**
   ```
   Click on "Cleanup Tools" in the sidebar
   Select either "Data Cleanup" or "Image Cleanup" tab
   ```

### Data Cleanup Tab

#### Step 1: Scan for Orphaned Data
```
1. Click "Scan Database" button
2. Wait for the scan to complete
3. Review the results showing orphaned records by type
```

#### Step 2: Review Results
```
- Expand each category to see specific orphaned records
- Review the details of what will be deleted
- Check the total count of orphaned records
```

#### Step 3: Cleanup
```
1. Click "Clean Up" button
2. Confirm the deletion in the dialog
3. Wait for cleanup to complete
4. Review the cleanup summary
```

### Image Cleanup Tab

#### Step 1: Get Storage Stats
```
1. Click "Get Stats" button
2. Review total images and storage usage
3. Check distribution by image type
```

#### Step 2: Cleanup Orphaned Images
```
1. Click "Cleanup Images" button
2. Confirm the deletion in the dialog
3. Wait for cleanup to complete
4. Review the cleanup results
```

## 💻 Server-Side Script Cleanup

### Prerequisites

```bash
# Ensure you have Node.js installed
node --version

# Ensure Firebase Admin SDK is set up
# Place your serviceAccountKey.json in the project root
```

### Running the Script

#### Dry Run (Safe Preview)
```bash
# Preview what would be deleted without actually deleting
node cleanup_orphaned_data.js --dry-run
```

#### Get Database Statistics
```bash
# View current database statistics
node cleanup_orphaned_data.js --stats
```

#### Execute Cleanup
```bash
# Actually delete orphaned data (PERMANENT)
node cleanup_orphaned_data.js --execute
```

### Script Output Example

```
🧹 Starting DRY RUN comprehensive cleanup...
⚠️ DRY RUN MODE - No data will actually be deleted

🔍 Finding orphaned chats...
📊 Found 5 orphaned chats
🔍 Finding orphaned chatbot conversations...
📊 Found 12 orphaned chatbot conversations
🔍 Finding orphaned notifications...
📊 Found 3 orphaned notifications

📊 ORPHANED DATA SUMMARY:
  - chats: 5 orphaned records
  - chatbot_conversations: 12 orphaned records
  - notifications: 3 orphaned records
  - TOTAL: 20 orphaned records

✅ Dry run complete. Run with --execute to actually delete the data.
```

## 📱 Flutter App Cleanup

### Using the DataCleanupService

```dart
import 'lib/services/data_cleanup_service.dart';

// Scan for orphaned data
final orphanedData = await DataCleanupService.findAllOrphanedData();

// Cleanup specific type
final deletedChats = await DataCleanupService.deleteOrphanedChats(
  orphanedData['chats'] ?? []
);

// Full cleanup (dry run)
final previewResults = await DataCleanupService.cleanupAllOrphanedData(dryRun: true);

// Full cleanup (live)
final cleanupResults = await DataCleanupService.cleanupAllOrphanedData(dryRun: false);
```

### Using the ImageCleanupService

```dart
import 'lib/services/image_cleanup_service.dart';

// Get storage statistics
final stats = await ImageCleanupService.getStorageStats();

// Find orphaned images by type
final orphanedProducts = await ImageCleanupService.findOrphanedProductImages();
final orphanedProfiles = await ImageCleanupService.findOrphanedProfileImages();

// Cleanup all orphaned images
final cleanupResults = await ImageCleanupService.cleanupOrphanedImages();
```

## 🔒 Safety Measures

### Before Running Cleanup

1. **Backup Your Database**
   ```bash
   # Export Firestore data
   gcloud firestore export gs://your-backup-bucket/backup-$(date +%Y%m%d)
   ```

2. **Run in Dry-Run Mode First**
   ```bash
   # Always preview changes first
   node cleanup_orphaned_data.js --dry-run
   ```

3. **Test on Development Environment**
   ```bash
   # Test the cleanup process on non-production data first
   ```

### During Cleanup

1. **Monitor Progress**
   - Watch console output for errors
   - Check for unexpected behavior
   - Stop if something seems wrong

2. **Verify Results**
   - Check that expected data was deleted
   - Ensure no important data was removed
   - Validate application functionality

### After Cleanup

1. **Verify Application Function**
   - Test core app features
   - Check user flows
   - Monitor for errors

2. **Monitor Performance**
   - Check database performance
   - Verify reduced storage usage
   - Monitor query speeds

## 🔧 Troubleshooting

### Common Issues

#### "Authentication Error"
```bash
# Solution: Ensure serviceAccountKey.json is in the project root
# and has the correct permissions
```

#### "Collection Not Found"
```bash
# Solution: The collection might not exist yet
# This is normal for new applications
```

#### "Batch Size Too Large"
```bash
# Solution: The script automatically handles batch sizes
# If this persists, reduce the batch size in the script
```

#### "Permission Denied"
```bash
# Solution: Ensure your service account has Firestore admin permissions
```

### Performance Issues

#### Large Datasets
```bash
# For very large datasets (100k+ records):
1. Run cleanup during low-traffic hours
2. Consider running in smaller batches
3. Monitor database performance during cleanup
```

#### Memory Issues
```bash
# If the script runs out of memory:
1. Increase Node.js memory limit: --max-old-space-size=4096
2. Process data in smaller chunks
3. Run cleanup for specific collections only
```

### Recovery Procedures

#### If Important Data Was Deleted
```bash
# Restore from backup
gcloud firestore import gs://your-backup-bucket/backup-YYYYMMDD
```

#### If Cleanup Incomplete
```bash
# Re-run the cleanup script
node cleanup_orphaned_data.js --execute
```

## 📈 Best Practices

### Regular Maintenance
- Run cleanup monthly or quarterly
- Monitor orphaned data growth
- Set up automated alerts for large orphan counts

### Data Hygiene
- Implement cascading deletes in your application
- Clean up related data when users/products are deleted
- Use database triggers for automatic cleanup

### Monitoring
- Track orphaned data metrics
- Set up alerts for unusual growth
- Monitor cleanup performance over time

## 🔄 Automation

### Scheduled Cleanup

You can automate the cleanup process using cron jobs or cloud functions:

```bash
# Example cron job (runs monthly)
0 2 1 * * cd /path/to/project && node cleanup_orphaned_data.js --execute >> cleanup.log 2>&1
```

### Cloud Function Example

```javascript
const functions = require('firebase-functions');
const OrphanedDataCleanup = require('./cleanup_orphaned_data');

exports.scheduledCleanup = functions.pubsub
  .schedule('0 2 1 * *') // Monthly at 2 AM
  .onRun(async (context) => {
    const cleanup = new OrphanedDataCleanup();
    cleanup.dryRun = false;
    const results = await cleanup.cleanupOrphanedData();
    console.log('Automated cleanup results:', results);
  });
```

## 📞 Support

If you encounter issues with the cleanup process:

1. Check the troubleshooting section above
2. Review the console output for specific error messages
3. Test on a development environment first
4. Ensure you have proper backups before proceeding

## ⚠️ Important Warnings

- **ALWAYS backup your database before running cleanup**
- **Test on development environment first**
- **Review dry-run results carefully**
- **Some deletions are irreversible**
- **Monitor application behavior after cleanup**

---

*Last updated: December 2024*
