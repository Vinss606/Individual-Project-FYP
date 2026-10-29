import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The dark green top bar with the star logo, greeting, notification bell,
/// role switcher and log-out button.
class MyKasihHeader extends StatelessWidget {
  const MyKasihHeader({
    super.key,
    required this.userName,
    required this.onLogout,
    this.onOpenNotifications,
    this.isAdmin = false,
    this.onToggleAdmin,
    this.child,
  });

  final String userName;
  final VoidCallback onLogout;
  final VoidCallback? onOpenNotifications;
  final bool isAdmin;
  final VoidCallback? onToggleAdmin;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: AppColors.gold, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'BantuLife',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Selamat datang, $userName',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onOpenNotifications != null)
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 20),
                    tooltip: 'Notifikasi & Amaran',
                    onPressed: onOpenNotifications,
                  ),
                if (onToggleAdmin != null)
                  IconButton(
                    icon: Icon(
                      isAdmin
                          ? Icons.admin_panel_settings
                          : Icons.admin_panel_settings_outlined,
                      color: isAdmin ? AppColors.gold : Colors.white70,
                      size: 20,
                    ),
                    tooltip: isAdmin ? 'Tukar ke Mod Pengguna' : 'Portal Pentadbir',
                    onPressed: onToggleAdmin,
                  ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onLogout,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.logout, size: 14),
                  label: const Text('Keluar', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 16),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}
