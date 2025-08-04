import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  // Email configuration - you should move these to environment variables
  static const String _gmailUsername = 'xlabxxk2@gmail.com';
  static const String _gmailAppPassword = 'sqxslllycocwkdof';
  // static const String _gmailAppPassword = 'sqxs llly cocw kdof';

  // Alternative: Use a different email provider
  static const String _outlookUsername = 'your-outlook@outlook.com';
  static const String _outlookPassword = 'your-password';

  static SmtpServer _getSmtpServer({String provider = 'gmail'}) {
    switch (provider.toLowerCase()) {
      case 'gmail':
        return gmail(_gmailUsername, _gmailAppPassword);
      case 'outlook':
        return SmtpServer(
          'smtp-mail.outlook.com',
          port: 587,
          username: _outlookUsername,
          password: _outlookPassword,
          allowInsecure: false,
          ssl: false,
        );
      case 'yahoo':
        return SmtpServer(
          'smtp.mail.yahoo.com',
          port: 587,
          username: 'your-yahoo@yahoo.com',
          password: 'your-password',
          allowInsecure: false,
          ssl: false,
        );
      default:
        return gmail(_gmailUsername, _gmailAppPassword);
    }
  }

  static Future<bool> sendEmployeeInvitation({
    required String employeeEmail,
    required String employeeName,
    required String password,
    required String organizationName,
    String provider = 'gmail',
  }) async {
    try {
      debugPrint('EmailService: Sending invitation to $employeeEmail via $provider');

      final smtpServer = _getSmtpServer(provider: provider);

      final message = Message()
        ..from = Address(_getSenderEmail(provider), organizationName)
        ..recipients.add(employeeEmail)
        ..subject = '$organizationName-ээс ажилд урилга'
        ..text = _getPlainTextContent(employeeName, organizationName, employeeEmail, password)
        ..html = _getHtmlContent(employeeName, organizationName, employeeEmail, password);

      final sendReport = await send(message, smtpServer).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('Email sending timeout');
        },
      );

      debugPrint('EmailService: Email sent successfully - $sendReport');
      return true;

    } on MailerException catch (e) {
      debugPrint('EmailService MailerException: $e');
      for (var problem in e.problems) {
        debugPrint('Problem: ${problem.code} - ${problem.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('EmailService Error: $e');
      return false;
    }
  }

  static String _getSenderEmail(String provider) {
    switch (provider.toLowerCase()) {
      case 'gmail':
        return _gmailUsername;
      case 'outlook':
        return _outlookUsername;
      default:
        return _gmailUsername;
    }
  }

  static String _getPlainTextContent(String employeeName, String organizationName, String employeeEmail, String password) {
    return '''
Сайн байна уу $employeeName,

$organizationName байгууллагаас таныг тэдний багт нэгдэхийг урьж байна!

Таны нэвтрэх мэдээлэл:
- Имэйл: $employeeEmail
- Нууц үг: $password

Системд нэвтэрснээр та ажлын цагаа бүртгэж, байгууллагынхаа системд хандах боломжтой болно.

АНХААР: Аюулгүй байдлын үүднээс эхний нэвтрэлтийн дараа нууц үгээ солихыг зөвлөж байна.

Хэрэв танд асуулт байвал $organizationName-ын удирдлагатай холбогдоно уу.

Баярлалаа,
$organizationName багийн хэсэг
    ''';
  }

  static String _getHtmlContent(String employeeName, String organizationName, String employeeEmail, String password) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ажилд урилга</title>
</head>
<body style="margin: 0; padding: 20px; font-family: Arial, sans-serif; background-color: #f5f5f5;">
    <div style="max-width: 600px; margin: 0 auto; background-color: white; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <!-- Header -->
        <div style="background: linear-gradient(135deg, #1976d2, #42a5f5); padding: 30px; text-align: center;">
            <h1 style="color: white; margin: 0; font-size: 28px; font-weight: bold;">Ажилд урилга</h1>
            <p style="color: #e3f2fd; margin: 10px 0 0 0; font-size: 16px;">$organizationName</p>
        </div>
        
        <!-- Content -->
        <div style="padding: 40px;">
            <p style="font-size: 18px; color: #333; margin-bottom: 20px;">Сайн байна уу <strong style="color: #1976d2;">$employeeName</strong>,</p>
            
            <p style="font-size: 16px; color: #555; line-height: 1.6; margin-bottom: 30px;">
                <strong>$organizationName</strong> байгууллагаас таныг тэдний багт нэгдэхийг урьж байна! 
                Бид танай мэргэжлийг үнэлж, хамтран ажиллахыг хүсч байна.
            </p>
            
            <!-- Credentials Box -->
            <div style="background: linear-gradient(135deg, #e3f2fd, #f8f9fa); border: 2px solid #1976d2; border-radius: 12px; padding: 30px; margin: 30px 0;">
                <h3 style="color: #1976d2; margin: 0 0 20px 0; font-size: 20px; text-align: center;">🔐 Таны нэвтрэх мэдээлэл</h3>
                
                <div style="background: white; border-radius: 8px; padding: 20px; margin: 15px 0;">
                    <p style="margin: 0 0 10px 0; color: #666; font-size: 14px;">Имэйл хаяг:</p>
                    <p style="margin: 0; font-size: 16px; font-weight: bold; color: #1976d2;">$employeeEmail</p>
                </div>
                
                <div style="background: white; border-radius: 8px; padding: 20px; margin: 15px 0;">
                    <p style="margin: 0 0 10px 0; color: #666; font-size: 14px;">Нууц үг:</p>
                    <p style="margin: 0; font-size: 24px; font-weight: bold; color: #d32f2f; font-family: monospace; letter-spacing: 2px; text-align: center; background: #fff3e0; padding: 15px; border-radius: 6px; border: 2px dashed #ff9800;">$password</p>
                </div>
            </div>
            
            <!-- Instructions -->
            <div style="background: #f8f9fa; border-left: 4px solid #4caf50; padding: 20px; margin: 30px 0; border-radius: 4px;">
                <h4 style="color: #2e7d32; margin: 0 0 15px 0; font-size: 16px;">📱 Дараагийн алхамууд:</h4>
                <ol style="color: #555; margin: 0; padding-left: 20px; line-height: 1.6;">
                    <li>Дээрх имэйл болон нууц үгээр системд нэвтэрнэ үү</li>
                    <li>Эхний нэвтрэлтийн дараа шинэ нууц үг үүсгэнэ үү</li>
                    <li>Өөрийн профайлын мэдээллээ шинэчилнэ үү</li>
                    <li>Ажлын цагийн хуваарийг танилцаж үзнэ үү</li>
                </ol>
            </div>
            
            <!-- Warning -->
            <div style="background: #fff3cd; border: 1px solid #ffc107; border-radius: 8px; padding: 20px; margin: 30px 0;">
                <p style="margin: 0; color: #856404; font-size: 14px;">
                    <strong>⚠️ Анхаар:</strong> Аюулгүй байдлын үүднээс эхний нэвтрэлтийн дараа заавал нууц үгээ солино уу. 
                    Нууц үгээ хэнтэй ч хуваалцахгүй байхыг зөвлөж байна.
                </p>
            </div>
            
            <p style="font-size: 16px; color: #555; margin-top: 30px;">
                Хэрэв танд асуулт эсвэл тусламж хэрэгтэй бол <strong>$organizationName</strong>-ын удирдлагатай холбогдоно уу.
            </p>
            
            <p style="font-size: 16px; color: #1976d2; margin-top: 30px; text-align: center;">
                <strong>Таныг багтаа угтан авахыг тэсэн ядан хүлээж байна! 🎉</strong>
            </p>
        </div>
        
        <!-- Footer -->
        <div style="background: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e0e0e0;">
            <p style="margin: 0; color: #666; font-size: 12px;">
                Энэ имэйл нь $organizationName системээс автоматаар илгээгдсэн.<br>
                ${DateTime.now().toString().split('.')[0]}
            </p>
        </div>
    </div>
</body>
</html>
    ''';
  }
}