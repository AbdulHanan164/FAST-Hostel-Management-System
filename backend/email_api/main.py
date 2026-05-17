"""
FAST Hostel — Email OTP API  (Flask + Gmail SMTP + Firebase Admin)
Sends 6-digit OTP codes and handles password reset.

Run:
    python main.py          → http://localhost:8000

Endpoints:
    GET  /                          → health check
    POST /send-otp                  → send OTP email
    POST /check-email               → verify Firebase account exists
    POST /reset-password            → update Firebase user password (Admin SDK)

Firebase Admin setup:
    1. Firebase Console → Project Settings → Service accounts
    2. "Generate new private key" → download JSON
    3. Save as:  backend/email_api/serviceAccountKey.json
"""

import os
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

# ── Load .env ─────────────────────────────────────────────────────────────────
load_dotenv()

EMAIL_USER      = os.getenv("EMAIL_USER", "")
EMAIL_PASS      = os.getenv("EMAIL_PASS", "")
EMAIL_FROM_NAME = os.getenv("EMAIL_FROM_NAME", "FAST Hostel System")
ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3000,http://localhost:5000,http://127.0.0.1:3000",
).split(",")

if not EMAIL_USER or not EMAIL_PASS:
    raise RuntimeError(
        "EMAIL_USER and EMAIL_PASS must be set in .env before starting."
    )

# ── Firebase Admin SDK (optional — only needed for /check-email & /reset-password)
_firebase_admin_ready = False
try:
    import firebase_admin
    from firebase_admin import credentials, auth as firebase_auth

    _SERVICE_ACCOUNT = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")
    if os.path.exists(_SERVICE_ACCOUNT):
        cred = credentials.Certificate(_SERVICE_ACCOUNT)
        firebase_admin.initialize_app(cred)
        _firebase_admin_ready = True
        print("[Firebase Admin] Initialized from serviceAccountKey.json")
    else:
        print(
            "[Firebase Admin] serviceAccountKey.json not found. "
            "/check-email and /reset-password will return 503."
        )
except ImportError:
    print("[Firebase Admin] firebase-admin not installed. Run: pip install firebase-admin")


# ── Flask app ─────────────────────────────────────────────────────────────────
app = Flask(__name__)
CORS(app, origins=[o.strip() for o in ALLOWED_ORIGINS])


# ── HTML email template ───────────────────────────────────────────────────────
def _build_html(to_name: str, otp_code: str, subject_line: str = "Verification Code") -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>{subject_line}</title>
</head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 0;">
    <tr><td align="center">
      <table width="520" cellpadding="0" cellspacing="0"
             style="background:#fff;border-radius:16px;overflow:hidden;
                    box-shadow:0 4px 24px rgba(15,34,68,.12);">

        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#0F2244 0%,#1B3A6B 60%,#2E5FA3 100%);
                     padding:32px 40px;text-align:center;">
            <h1 style="margin:0;color:#fff;font-size:22px;font-weight:800;letter-spacing:.5px;">
              FAST Hostel System
            </h1>
            <p style="margin:6px 0 0;color:rgba(255,255,255,.75);font-size:13px;">
              FAST-NUCES · CFD Campus
            </p>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="padding:36px 40px 28px;">
            <p style="margin:0 0 8px;font-size:16px;color:#1B3A6B;font-weight:700;">
              Hi {to_name},
            </p>
            <p style="margin:0 0 24px;font-size:14px;color:#4B5563;line-height:1.6;">
              Use the code below to <strong>{subject_line.lower()}</strong>.
              This code is valid for <strong>10 minutes</strong>.
            </p>

            <!-- OTP box -->
            <div style="background:#f0f4f8;border-radius:12px;padding:28px;
                        text-align:center;margin:0 0 24px;">
              <p style="margin:0 0 8px;font-size:12px;color:#6B7280;
                         letter-spacing:1.5px;text-transform:uppercase;">
                {subject_line}
              </p>
              <p style="margin:0;font-size:44px;font-weight:900;
                         letter-spacing:14px;color:#1B3A6B;">
                {otp_code}
              </p>
            </div>

            <p style="margin:0;font-size:13px;color:#9CA3AF;line-height:1.6;">
              If you did not request this, you can safely ignore this email.
              Never share this code with anyone.
            </p>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="background:#f9fafb;padding:20px 40px;
                     border-top:1px solid #E5E7EB;text-align:center;">
            <p style="margin:0;font-size:12px;color:#9CA3AF;">
              &copy; 2025 FAST Hostel Management System &bull; FAST-NUCES, CFD Campus
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>"""


# ── SMTP helper ───────────────────────────────────────────────────────────────
def _send_smtp(to_email: str, to_name: str, otp_code: str,
               subject_prefix: str = "Verification") -> None:
    subject = f"{otp_code} — Your FAST Hostel {subject_prefix} Code"
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"]    = f"{EMAIL_FROM_NAME} <{EMAIL_USER}>"
    msg["To"]      = to_email

    plain = (
        f"Hi {to_name},\n\n"
        f"Your FAST Hostel {subject_prefix.lower()} code is: {otp_code}\n\n"
        f"Valid for 10 minutes. Do not share this code.\n\n"
        f"— FAST Hostel System"
    )
    msg.attach(MIMEText(plain, "plain"))
    msg.attach(MIMEText(
        _build_html(to_name, otp_code, f"{subject_prefix} Code"), "html"
    ))

    ctx = ssl.create_default_context()
    with smtplib.SMTP("smtp.gmail.com", 587) as server:
        server.ehlo()
        server.starttls(context=ctx)
        server.login(EMAIL_USER, EMAIL_PASS)
        server.sendmail(EMAIL_USER, to_email, msg.as_string())


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/")
def health():
    return jsonify({
        "status": "ok",
        "service": "FAST Hostel Email API",
        "firebase_admin": _firebase_admin_ready,
    })


@app.post("/send-otp")
def send_otp():
    """Send signup verification OTP."""
    data = request.get_json(silent=True) or {}
    to_email = (data.get("to_email") or "").strip()
    to_name  = (data.get("to_name")  or "Student").strip()
    otp_code = (data.get("otp_code") or "").strip()

    if not to_email:
        return jsonify({"success": False, "message": "to_email is required."}), 422
    if not otp_code or len(otp_code) != 6 or not otp_code.isdigit():
        return jsonify({"success": False, "message": "otp_code must be exactly 6 digits."}), 422

    try:
        _send_smtp(to_email, to_name, otp_code, "Verification")
        return jsonify({"success": True, "message": "OTP sent successfully."})
    except smtplib.SMTPAuthenticationError:
        return jsonify({"success": False, "message": "SMTP authentication failed."}), 500
    except Exception as e:
        return jsonify({"success": False, "message": f"Failed to send email: {e}"}), 500


@app.post("/check-email")
def check_email():
    """
    Check whether a Firebase account exists for the given email.
    Also sends a password-reset OTP if the account is found.
    Body: { "email": "...", "otp_code": "...", "to_name": "..." }
    """
    if not _firebase_admin_ready:
        return jsonify({
            "success": False,
            "message": "Firebase Admin SDK not configured. "
                       "Add serviceAccountKey.json to backend/email_api/.",
        }), 503

    data     = request.get_json(silent=True) or {}
    email    = (data.get("email")    or "").strip()
    otp_code = (data.get("otp_code") or "").strip()
    to_name  = (data.get("to_name")  or "Student").strip()

    if not email:
        return jsonify({"success": False, "message": "email is required."}), 422
    if not otp_code or len(otp_code) != 6 or not otp_code.isdigit():
        return jsonify({"success": False, "message": "otp_code must be exactly 6 digits."}), 422

    # Check Firebase account
    try:
        firebase_auth.get_user_by_email(email)   # raises if not found
    except firebase_auth.UserNotFoundError:
        return jsonify({
            "success": False,
            "message": "No account found with this email. Please sign up first.",
        }), 404
    except Exception as e:
        return jsonify({"success": False, "message": f"Firebase error: {e}"}), 500

    # Account exists — send password-reset OTP
    try:
        _send_smtp(email, to_name, otp_code, "Password Reset")
        return jsonify({"success": True, "message": "Password reset OTP sent."})
    except smtplib.SMTPAuthenticationError:
        return jsonify({"success": False, "message": "SMTP authentication failed."}), 500
    except Exception as e:
        return jsonify({"success": False, "message": f"Failed to send email: {e}"}), 500


@app.post("/reset-password")
def reset_password():
    """
    Update a Firebase user's password using Admin SDK.
    Body: { "email": "...", "new_password": "..." }
    Called only after OTP is verified on the client.
    """
    if not _firebase_admin_ready:
        return jsonify({
            "success": False,
            "message": "Firebase Admin SDK not configured. "
                       "Add serviceAccountKey.json to backend/email_api/.",
        }), 503

    data         = request.get_json(silent=True) or {}
    email        = (data.get("email")        or "").strip()
    new_password = (data.get("new_password") or "").strip()

    if not email:
        return jsonify({"success": False, "message": "email is required."}), 422
    if len(new_password) < 8:
        return jsonify({"success": False, "message": "Password must be at least 8 characters."}), 422

    try:
        user = firebase_auth.get_user_by_email(email)
        firebase_auth.update_user(user.uid, password=new_password)
        return jsonify({"success": True, "message": "Password updated successfully."})
    except firebase_auth.UserNotFoundError:
        return jsonify({"success": False, "message": "No account found with this email."}), 404
    except Exception as e:
        return jsonify({"success": False, "message": f"Failed to reset password: {e}"}), 500


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 52)
    print("  FAST Hostel — Email OTP API")
    print("  URL  : http://localhost:8000")
    print("  Docs : GET / | POST /send-otp")
    print("         POST /check-email | POST /reset-password")
    print("=" * 52)
    app.run(host="0.0.0.0", port=8000, debug=True)
