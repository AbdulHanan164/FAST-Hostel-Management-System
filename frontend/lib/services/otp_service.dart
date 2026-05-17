import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/web_config.dart';

/// Handles OTP generation and email delivery via EmailJS.
class OtpService {
  static const String _emailJsUrl =
      'https://api.emailjs.com/api/v1.0/email/send';

  /// Generates a cryptographically random 6-digit OTP string.
  static String generateOtp() {
    final rng = Random.secure();
    final code = rng.nextInt(900000) + 100000; // always 6 digits
    return code.toString();
  }

  /// Sends [otp] to [email] via EmailJS.
  ///
  /// Returns `true` on success, throws an exception with a human-readable
  /// message on failure so the UI can show a proper error.
  static Future<bool> sendOtpEmail({
    required String email,
    required String otp,
    required String recipientName,
  }) async {
    try {
      const serviceId = WebConfig.emailJsServiceId;
      const templateId = WebConfig.emailJsTemplateId;
      const publicKey = WebConfig.emailJsPublicKey;

      // Warn in debug mode if credentials are still placeholders
      if (serviceId.startsWith('YOUR_') ||
          templateId.startsWith('YOUR_') ||
          publicKey.startsWith('YOUR_')) {
        debugPrint(
          '[OtpService] ⚠ EmailJS credentials not configured in WebConfig. '
          'OTP will only be printed to console for testing.',
        );
        debugPrint('[OtpService] TEST OTP for $email → $otp');
        // Return true so the UI flow still works during development
        return true;
      }

      final response = await http
          .post(
            Uri.parse(_emailJsUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': serviceId,
              'template_id': templateId,
              'user_id': publicKey,
              'template_params': {
                'to_email': email,
                'to_name': recipientName,
                'otp_code': otp,
                'app_name': 'FAST Hostel System',
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('[OtpService] OTP email sent successfully to $email');
        return true;
      } else {
        debugPrint(
          '[OtpService] EmailJS error ${response.statusCode}: ${response.body}',
        );
        throw Exception(
          'Failed to send OTP email (status ${response.statusCode}). '
          'Please try again.',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error while sending OTP. Check your connection.');
    }
  }
}
