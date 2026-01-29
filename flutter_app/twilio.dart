import 'package:http/http.dart' as http;
import 'dart:convert';

class TwilioService {
  final String accountSid = 'YOUR_TWILIO_ACCOUNT_SID';
  final String authToken = 'YOUR_TWILIO_AUTH_TOKEN';
  final String twilioNumber = 'YOUR_TWILIO_PHONE_NUMBER';

  Future<void> sendSMS(String recipient, String message) async {
    final url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'From': twilioNumber,
        'To': recipient,
        'Body': message,
      },
    );

    if (response.statusCode == 201) {
      print('✅ SMS sent successfully');
    } else {
      print('❌ Failed to send SMS: ${response.body}');
    }
  }
}