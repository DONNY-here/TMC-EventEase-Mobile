import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_config.dart';
import 'services/api_auth_service.dart';
import 'services/auth_token_storage.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'models/tmc_departments.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'services/qr_verification_service.dart';
import 'services/auth_service.dart';
import 'services/demo_session_storage.dart';
import 'app_theme_controller.dart';
import 'eventease_profile_view.dart';


part 'config_and_data.dart';
part 'app.dart';
part 'session_gate.dart';
part 'helpers.dart';
part 'login_page.dart';
part 'forgot_password_page.dart';
part 'register_page.dart';
part 'main_page.dart';
part 'dashboard_page.dart';
part 'general_assembly_fine_page.dart';
part 'dashboard_widgets.dart';
part 'events_page.dart';
part 'event_details_page.dart';
part 'event_details_widgets.dart';
part 'my_events_page.dart';
part 'announcements_page.dart';
part 'profile_page.dart';
part 'edit_profile_page.dart';
part 'qr_scanner_page.dart';
part 'evaluation_page.dart';
part 'empty_state.dart';
part 'e_certificate_page.dart';
part 'student_qr_pass_page.dart';
part 'scanner_profile_page.dart';

final AuthService authService = AuthService();

final DemoSessionStorage demoSessionStorage = DemoSessionStorage();

final AuthTokenStorage authTokenStorage = AuthTokenStorage();

void main() {
  runApp(const EventEaseApp());
}
