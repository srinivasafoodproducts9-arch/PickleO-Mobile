import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../utils/auth_guard.dart';
import '../screens/profile_screen.dart';

/// Reusable User Avatar widget that dynamically resolves:
/// 1. Remote `avatarUrl` from backend when available.
/// 2. Local uploaded `localAvatarBytes`.
/// 3. Clear avatar icon (person icon) if no image is available or when not logged in.
/// 4. Tap handling: if not logged in -> open Login screen; if logged in -> open Profile screen or custom onTap.
class UserAvatar extends StatelessWidget {
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.radius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final localAvatarBytes = appState.localAvatarBytes;
    final avatarUrl = appState.avatarUrl;
    final isLoggedIn = appState.isLoggedIn;

    // Standard fallback avatar icon (clean person icon in brand colors)
    final Widget avatarIconFallback = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFEDE8),
        border: Border.all(
          color: const Color(0xFFFBD1C4),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Icon(
          isLoggedIn ? Icons.person_rounded : Icons.person_outline_rounded,
          size: radius * 1.25,
          color: const Color(0xFF964900),
        ),
      ),
    );

    Widget avatarWidget;

    if (localAvatarBytes != null && localAvatarBytes.isNotEmpty) {
      avatarWidget = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFBD1C4),
            width: 1.2,
          ),
          image: DecorationImage(
            image: MemoryImage(localAvatarBytes),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (avatarUrl != null &&
        avatarUrl.trim().isNotEmpty &&
        avatarUrl != 'string' &&
        avatarUrl != 'null' &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      avatarWidget = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFBD1C4),
            width: 1.2,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            avatarUrl.trim(),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => avatarIconFallback,
          ),
        ),
      );
    } else {
      // If profile image is not there, show avatar icon in all screens!
      avatarWidget = avatarIconFallback;
    }

    return InkWell(
      onTap: () {
        if (onTap != null) {
          requireAuth(context, onAuthenticated: onTap);
        } else {
          requireAuth(context, onAuthenticated: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProfileScreen(),
              ),
            );
          });
        }
      },
      customBorder: const CircleBorder(),
      child: avatarWidget,
    );
  }
}
