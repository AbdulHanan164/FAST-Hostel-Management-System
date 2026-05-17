import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Handles OTP generation and email delivery via the FAST Hostel Email API
/// (Flask + Gmail SMTP running on localhost:8000).
class OtpService {
  /// Base URL of the Flask email API.
  /// Change this to your deployed server URL in production.
  static const String _apiBaseUrl = 'http://localhost:8000';

  /// Generates a cryptographically random 6-digit OTP string.
  static String generateOtp() {
    final rng = Random.secure();
    final code = rng.nextInt(900000) + 100000; // always 6 digits
    return code.toString();
  }

  /// Sends [otp] to [email] via the Flask SMTP backend.
  ///
  /// Returns `true` on success.
  /// Throws an [Exception] with a human-readable message on failure.
  static Future<bool> sendOtpEmail({
    required String email,
    required String otp,
    required String recipientName,
  }) async {
    try {
      debugPrint('[OtpService] Sending OTP to $email via $_apiBaseUrl/send-otp');

      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to_email': email,
              'to_name': recipientName,
              'otp_code': otp,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          debugPrint('[OtpService] OTP sent successfully to $email');
          return true;
        }
        throw Exception(body['message'] ?? 'Failed to send OTP.');
      } else {
        // Try to parse error message from response body
        String errorMsg = 'Failed to send OTP (status ${response.statusCode}).';
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          errorMsg = body['message'] ?? errorMsg;
        } catch (_) {}
        debugPrint('[OtpService] Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } on http.ClientException catch (e) {
      throw Exception(
        'Cannot connect to email server. '
        'Make sure the backend is running (backend/email_api/start.bat). '
        'Details: ${e.message}',
      );
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Unexpected error sending OTP: $e');
    }
  }
}
