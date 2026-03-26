import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_scanner_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  
  Future<void> _acceptTerms(BuildContext context) async {
    // 1. Get the instance of SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    

    await prefs.setBool('terms_accepted', true);

  
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const QRScannerScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Terms & Conditions"),
        backgroundColor: const Color(0xFFB19CD9), // Light purple AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  '''
1. Introduction
These Terms and Conditions (“Terms”) govern the use of the mobile application (the “App”), which is designed to provide indoor and outdoor navigation assistance to visually impaired individuals through QR code scanning and location-based services. By downloading, installing, or using the App, you (“User”) agree to be bound by these Terms and the accompanying Privacy Policy, which collectively form a legally binding agreement between you and the App developer (“Developer,” “we,” “our,” or “us”).

If you do not agree to these Terms or the Privacy Policy, you must refrain from using the App.

2. Eligibility
The App is intended for general use and is not subject to age restrictions; however, Users under the age of 18 must obtain consent from a parent or legal guardian before use.

3. Scope of Services
The App provides navigation guidance by scanning QR codes located within premises and utilizing device location services to provide corresponding directional information. The App does not store personal data or retain navigation history.

4. User Obligations
By using the App, you agree:
a) To use the App only for lawful purposes;
b) To refrain from attempting to modify, reverse-engineer, or tamper with the App’s code or functionality;
c) To ensure your device meets the technical requirements for operating the App, including enabling camera and location permissions;
d) To remain aware of your surroundings and exercise caution at all times while navigating.

5. Accuracy of Information & Disclaimer
While the App is designed to assist with navigation, the Developer does not guarantee the accuracy, completeness, or timeliness of the navigation instructions provided. Environmental changes, damaged or misplaced QR codes, GPS inaccuracies, or other technical limitations may result in incorrect or incomplete directions.

The App should not be used as the sole source of navigation. Users must use additional assistive tools, mobility aids, and personal judgment to ensure safe travel. The Developer shall not be held liable for any injury, damage, or loss resulting from reliance on the App’s guidance.

6. Limitation of Liability
To the maximum extent permitted by applicable law, the Developer shall not be liable for any direct, indirect, incidental, special, consequential, or exemplary damages arising from or in connection with the use or inability to use the App, including but not limited to damages for loss of data, personal injury, or property damage.

7. Location Data Usage
The App requires access to your device’s location solely for the purpose of providing navigation assistance. Location data is used in real time and is not stored, logged, or shared with third parties.

8. Privacy Policy
a) Data Collection
The App does not collect personally identifiable information. The only data accessed is:
- Camera input (for QR code scanning)
- Device location (for navigation purposes)

b) Data Usage
The accessed data is processed locally on your device and used exclusively to generate real-time navigation instructions.

c) Data Storage and Sharing
No personal or location data is stored, retained, or transmitted to external servers. The Developer does not sell, trade, or share any data with third parties.

d) Permissions
You may disable location or camera permissions at any time; however, doing so will render the App’s navigation functionality inoperative.

e) Legal Compliance
This Privacy Policy complies with applicable data protection regulations, including but not limited to:
- India: Digital Personal Data Protection Act, 2023
- United States: Relevant state-level privacy laws (including California Consumer Privacy Act where applicable)

9. Intellectual Property Rights
All intellectual property rights in the App, including its design, software code, text, images, and trademarks, are owned by the Developer or licensed for use. No part of the App may be reproduced, distributed, or modified without prior written consent from the Developer.

10. Termination of Use
The Developer reserves the right to suspend or terminate a User’s access to the App at its sole discretion for violation of these Terms or any applicable law.

11. Governing Law and Jurisdiction
These Terms shall be governed by and construed in accordance with the laws of:
- India, for Users residing in India; and
- The United States, for Users residing in the United States.

Any disputes arising from these Terms shall be subject to the exclusive jurisdiction of the courts in Hyderabad, Telangana, India, for Indian Users, and in the state of California, USA, for US Users.

12. Amendments
The Developer reserves the right to update or amend these Terms and the Privacy Policy at any time without prior notice. Continued use of the App after changes are posted constitutes acceptance of those changes.
                  ''',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Times New Roman',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB19CD9), // Light purple button
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () => _acceptTerms(context),
              child: const Text(
                "I Accept",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
