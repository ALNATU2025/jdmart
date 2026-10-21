import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/session_provider.dart';
import 'auth_flow_screen.dart';

/// Opens sign-in if needed. Returns true when a user with a profile is signed in.
Future<bool> ensureLoggedIn(BuildContext context) async {
  if (context.read<SessionProvider>().isLoggedIn) return true;
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AuthFlowScreen()),
  );
  return ok == true;
}
