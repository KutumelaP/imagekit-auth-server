# Image Cleanup System Setup

## Overview
This system provides comprehensive image management and cleanup capabilities for your marketplace app, preventing storage bloat and reducing costs.

## Features
- **Storage Statistics**: Monitor total images, storage usage, and breakdown by type
- **Orphaned Image Detection**: Find images not referenced in your database
- **Automatic Cleanup**: Remove orphaned images in batches
- **Manual Management**: Delete specific images or user/product image sets
- **Real-time Monitoring**: Track cleanup results and storage changes

## Setup Instructions

### 1. Configure ImageKit API Keys
Edit `lib/config/imagekit_config.dart`:

```dart
class ImageKitConfig {
  // Replace with your actual ImageKit credentials
  static const String privateKey = 'private_your_actual_private_key_here';
  static const String publicKey = 'public_your_actual_public_key_here';
  static const String urlEndpoint = 'https://ik.imagekit.io/your_endpoint';
  
  // Enable automatic cleanup if desired
  static const bool enableAutomaticCleanup = true;
  static const Duration cleanupInterval = Duration(hours: 24);
}
```

### 2. Get Your ImageKit Credentials
1. Log into your [ImageKit Dashboard](https://imagekit.io/dashboard)
2. Go to **Developer Options** → **API Keys**
3. Copy your **Private Key** and **Public Key**
4. Note your **URL Endpoint**

### 3. Test the System
1. Build and run the admin dashboard
2. Navigate to **Image Management** in the sidebar
3. Click **Refresh Stats** to test API connectivity
4. If successful, you'll see storage statistics

## Usage

### Storage Statistics
- View total images and storage usage
- See breakdown by image type (products, profiles, stores, chats)
- Monitor orphaned image count

### Finding Orphaned Images
1. Click **Find Orphaned Images**
2. System scans for:
   - Product images without valid product IDs
   - Profile images without valid user IDs
   - Store images without valid seller IDs
   - Chat images without valid chat IDs

### Cleanup Process
1. **Automatic Cleanup**: Click **Cleanup All** to remove all orphaned images
2. **Manual Cleanup**: Delete specific images using the delete button
3. **Selective Cleanup**: Use individual cleanup methods for specific types

### Cleanup Methods Available
- `cleanupOrphanedImages()` - Remove all orphaned images
- `deleteProductImages(productId)` - Remove images for a specific product
- `deleteUserImages(userId)` - Remove all images for a specific user
- `deleteChatImages(chatId)` - Remove images for a specific chat

## Safety Features

### Database Validation
- All cleanup operations validate against your Firestore database
- Only removes images without valid references
- Prevents accidental deletion of active images

### Rate Limiting
- Built-in delays between API calls
- Configurable request limits
- Prevents API throttling

### Confirmation Required
- Cleanup operations require explicit user action
- Results are displayed before and after cleanup
- Individual image deletion requires confirmation

## Monitoring and Maintenance

### Regular Cleanup Schedule
- **Daily**: Check storage statistics
- **Weekly**: Run orphaned image detection
- **Monthly**: Perform full cleanup

### Storage Optimization
- Monitor growth patterns
- Set up alerts for storage thresholds
- Regular cleanup prevents exponential growth

## Troubleshooting

### Common Issues

#### API Authentication Error
```
Error: Failed to fetch images: 401
```
**Solution**: Verify your ImageKit private key is correct

#### No Images Found
```
No storage data available
```
**Solution**: Check your ImageKit file paths match the configuration

#### Cleanup Fails
```
Error during cleanup: Rate limit exceeded
```
**Solution**: Increase delay between requests in config

### Debug Mode
Enable debug logging by setting:
```dart
static const bool enableDebugLogging = true;
```

## Cost Benefits

### Before Cleanup
- Unused images accumulate indefinitely
- Storage costs grow exponentially
- No visibility into storage usage

### After Cleanup
- Automatic removal of orphaned images
- Reduced storage costs
- Better resource utilization
- Improved app performance

## Security Considerations

### API Key Protection
- Never commit API keys to version control
- Use environment variables in production
- Rotate keys regularly

### Access Control
- Only admin users can access cleanup tools
- All operations are logged
- Confirmation required for destructive actions

## Production Deployment

### Environment Variables
```bash
export IMAGEKIT_PRIVATE_KEY="your_private_key"
export IMAGEKIT_PUBLIC_KEY="your_public_key"
export IMAGEKIT_URL_ENDPOINT="your_endpoint"
```

### Monitoring
- Set up alerts for storage thresholds
- Monitor cleanup operation success rates
- Track storage cost reductions

## Support
For issues or questions:
1. Check the debug logs
2. Verify ImageKit configuration
3. Test with a small subset of images first
4. Contact support with error details

## Future Enhancements
- Scheduled automatic cleanup
- Advanced filtering options
- Bulk operations
- Storage analytics dashboard
- Integration with monitoring tools
