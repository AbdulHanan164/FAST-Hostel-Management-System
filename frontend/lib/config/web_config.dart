class WebConfig {
  // ── Cloudinary ────────────────────────────────────────────────────────────
  static const String cloudinaryCloudName = 'damuoi6ey';
  static const String cloudinaryUploadPreset = 'hostel_images';
  static const String cloudinaryApiKey = '619287257284318';
  // Note: NEVER include API Secret in web code

  // ── Email OTP API ─────────────────────────────────────────────────────────
  // OTP emails are sent via the Flask backend at backend/email_api/
  // Start it with: backend/email_api/start.bat  →  http://localhost:8000
  // See OtpService for the API base URL (lib/services/otp_service.dart)
}
