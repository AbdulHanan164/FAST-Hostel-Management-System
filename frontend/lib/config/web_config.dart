class WebConfig {
  // ── Cloudinary ────────────────────────────────────────────────────────────
  static const String cloudinaryCloudName = 'damuoi6ey';
  static const String cloudinaryUploadPreset = 'hostel_images';
  static const String cloudinaryApiKey = '619287257284318';
  // Note: NEVER include API Secret in web code

  // ── EmailJS (OTP email delivery) ─────────────────────────────────────────
  // Free account: https://www.emailjs.com
  // Steps:
  //  1. Create account at emailjs.com
  //  2. Add an Email Service (Gmail / Outlook) → copy Service ID
  //  3. Create an Email Template with variables:
  //       {{to_name}}, {{otp_code}}, {{app_name}}
  //     Set "To Email" field to: {{to_email}}
  //     → copy Template ID
  //  4. Go to Account → API Keys → copy Public Key
  //  5. Paste all three values below
  static const String emailJsServiceId  = 'YOUR_SERVICE_ID';   // e.g. 'service_abc123'
  static const String emailJsTemplateId = 'YOUR_TEMPLATE_ID';  // e.g. 'template_xyz789'
  static const String emailJsPublicKey  = 'YOUR_PUBLIC_KEY';   // e.g. 'AbCdEfGhIjKlMnOp'
}
