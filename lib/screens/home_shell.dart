import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/notification_sheet.dart';
import 'login_screen.dart';
import 'mykasih_screen.dart';
import 'jualan_rahmah_screen.dart';
import 'belanjawan_screen.dart';
import 'admin_screen.dart';

/// Hosts the 3 post-login tabs (MyKasih / Jualan Rahmah / Belanjawan)
/// and handles notifications & admin mode switching.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.apiService, required this.user});

  final ApiService apiService;
  final AppUser user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _isAdminMode = false;

  @override
  void initState() {
    super.initState();
    _isAdminMode = widget.user.isAdmin;
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(apiService: widget.apiService),
      ),
      (route) => false,
    );
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NotificationSheet(
        apiService: widget.apiService,
        onOpenTab: (tabIndex) => setState(() => _index = tabIndex),
      ),
    );
  }

  void _toggleAdminMode() {
    setState(() => _isAdminMode = !_isAdminMode);
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdminMode) {
      return AdminScreen(
        apiService: widget.apiService,
        user: widget.user,
        onBackToUserMode: () => setState(() => _isAdminMode = false),
      );
    }

    final screens = [
      MyKasihScreen(
        apiService: widget.apiService,
        user: widget.user,
        onLogout: _logout,
        onOpenNotifications: _openNotifications,
        isAdmin: widget.user.isAdmin,
        onToggleAdmin: _toggleAdminMode,
      ),
      JualanRahmahScreen(
        apiService: widget.apiService,
        user: widget.user,
        onLogout: _logout,
        onOpenNotifications: _openNotifications,
        isAdmin: widget.user.isAdmin,
        onToggleAdmin: _toggleAdminMode,
      ),
      BelanjawanScreen(
        apiService: widget.apiService,
        user: widget.user,
        onLogout: _logout,
        onOpenNotifications: _openNotifications,
        isAdmin: widget.user.isAdmin,
        onToggleAdmin: _toggleAdminMode,
        onNavigateTab: (tabIndex) => setState(() => _index = tabIndex),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: MyKasihBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
