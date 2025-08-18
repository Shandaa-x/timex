// FCM Configuration
class FCMConfig {
  // For FCM API v1, we need to use OAuth2 instead of server key
  // The project ID from your Firebase Console
  static const String projectId = 'timex-9ce03'; // Your Firebase project ID
  
  // Since we're using the new FCM API, we don't need the server key
  // Instead, Firebase Admin SDK handles authentication automatically
  
  // FCM HTTP API v1 endpoint
  static String get fcmEndpoint => 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
  
  // For now, we'll use the Web Push certificate approach
  // Click "Generate key pair" in your Firebase Console to get these
  static const String vapidKey = ''; // Will be generated when you click "Generate key pair"
  
  // Check if FCM is properly configured
  static bool get isConfigured => projectId.isNotEmpty;
}