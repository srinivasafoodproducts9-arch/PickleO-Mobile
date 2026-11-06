import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../screens/auth_screen.dart';

/// Checks if the user is authenticated.
/// If authenticated, immediately invokes [onAuthenticated] (if provided) and returns true.
/// If not authenticated, navigates to [AuthScreen(isOptional: true)].
/// Upon successful login and profile completion, pops [AuthScreen] and invokes [onAuthenticated] (if provided).
bool requireAuth(BuildContext context, {VoidCallback? onAuthenticated}) {
  final appState = AppStateProvider.of(context);
  if (appState.isLoggedIn) {
    onAuthenticated?.call();
    return true;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AuthScreen(
        isOptional: true,
        onLoginSuccess: () {
          Navigator.of(context).pop();
          onAuthenticated?.call();
        },
      ),
    ),
  );
  return false;
}
