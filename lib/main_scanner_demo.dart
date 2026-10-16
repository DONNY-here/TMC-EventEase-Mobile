import 'package:flutter/material.dart';
import 'main.dart' as eventease;

void main() {
  eventease.savedUserRole = 'scanner';

  runApp(const eventease.EventEaseApp(scannerDemoMode: true));
}
