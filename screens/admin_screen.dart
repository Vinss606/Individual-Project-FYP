import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/verification_badge.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.apiService,
    required this.user,
    required this.onBackToUserMode,
  });

  final ApiService apiService;
  final AppUser user;
  final VoidCallback onBackToUserMode;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Event form fields
  final _eventNameController = TextEditingController(
      text: 'Jualan Rahmah Madani Butterworth');
  final _eventOrganiserController = TextEditingController(
      text: 'MBSP & KPDN Seberang Perai');
  final _eventAddressController = TextEditingController(
      text: 'Dataran Butterworth, Jalan Bagan Luar');
  final _eventStateController =
      TextEditingController(text: 'Pulau Pinang');
  final _eventDistrictController =
      TextEditingController(text: 'Seberang Perai Utara');
  DateTime _eventDate = DateTime.now().add(const Duration(days: 13));

  // Merchant form fields
  final _merchantNameController = TextEditingController(
      text: 'Dewan Komuniti Butterworth');
  final _merchantAddressController = TextEditingController(
      text: 'Jalan Bagan Luar, 10350 Butterworth');

  bool _isTestingEngine = false;
  VerificationReport? _lastReport;

  // Simulated Reschedule fields
  String _simulateEventId = 'PJRM-DEMO';
  DateTime _rescheduleNewDate = DateTime.now().add(const Duration(days: 15));
  String? _rescheduleFeedback;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventNameController.dispose();
    _eventOrganiserController.dispose();
    _eventAddressController.dispose();
    _eventStateController.dispose();
    _eventDistrictController.dispose();
    _merchantNameController.dispose();
    _merchantAddressController.dispose();
    super.dispose();
  }

  Future<void> _runEventVerification() async {
    setState(() {
      _isTestingEngine = true;
      _lastReport = null;
    });
    try {
      final payload = {
        'name': _eventNameController.text.trim(),
        'organiser': _eventOrganiserController.text.trim(),
        'address': _eventAddressController.text.trim(),
        'state': _eventStateController.text.trim(),
        'district': _eventDistrictController.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(_eventDate),
      };
      final report = await widget.apiService.verifyEvent(payload);
      setState(() {
        _lastReport = report;
        _isTestingEngine = false;
      });
      _showReportDialog(report);
    } catch (e) {
      setState(() => _isTestingEngine = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat verifikasi: $e')),
      );
    }
  }

  Future<void> _saveEvent() async {
    try {
      final payload = {
        'name': _eventNameController.text.trim(),
        'organiser': _eventOrganiserController.text.trim(),
        'address': _eventAddressController.text.trim(),
        'state': _eventStateController.text.trim(),
        'district': _eventDistrictController.text.trim(),
        'latitude': 5.3995,
        'longitude': 100.3642,
        'date': DateFormat('yyyy-MM-dd').format(_eventDate),
        'start_time': '08:00',
        'end_time': '13:00',
        'target_families': 400,
        'price_list': [
          {'name': 'Beras Super 5kg', 'controlled_price': 12.0, 'market_price': 18.0},
          {'name': 'Minyak Masak 2L', 'controlled_price': 6.5, 'market_price': 9.5},
        ],
        'run_verification': true,
      };
      await widget.apiService.createEvent(payload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🟢 Acara berjaya disahkan & diterbitkan!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat: $e')),
      );
    }
  }

  Future<void> _runMerchantVerification() async {
    setState(() {
      _isTestingEngine = true;
      _lastReport = null;
    });
    try {
      final payload = {
        'name': _merchantNameController.text.trim(),
        'address': _merchantAddressController.text.trim(),
      };
      final report = await widget.apiService.verifyMerchant(payload);
      setState(() {
        _lastReport = report;
        _isTestingEngine = false;
      });
      _showReportDialog(report);
    } catch (e) {
      setState(() => _isTestingEngine = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat: $e')),
      );
    }
  }

  void _showReportDialog(VerificationReport report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              VerificationStatusHelper.getBadgeIcon(report.status),
              color: VerificationStatusHelper.getBadgeColor(report.status),
            ),
            const SizedBox(width: 8),
            Text('Keputusan Pengesahan: ${report.status}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VerificationStatusHelper.getBadgeBgColor(report.status),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Skor Keseluruhan:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${report.score.toStringAsFixed(1)} / 100',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: VerificationStatusHelper.getBadgeColor(report.status),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Sumber Rasmi: ${report.source}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              Text('Tarikh Semakan: ${report.lastVerified}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              const Text('Pecahan Skor Algoritma (Level 2):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...report.breakdown.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('• ${e.key.replaceAll('_', ' ').toUpperCase()}:',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        Text('${e.value}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              Text('Ulasan Enjin: ${report.details}',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        title: const Text('Portal Pentadbir & Enjin Verifikasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali ke Mod Pengguna',
          onPressed: widget.onBackToUserMode,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.storefront, size: 18), text: 'Jualan Rahmah'),
            Tab(icon: Icon(Icons.inventory_2, size: 18), text: 'Pusat MyKasih'),
            Tab(icon: Icon(Icons.notification_important, size: 18), text: 'Ujian Jadual'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventVerificationTab(),
          _buildMerchantVerificationTab(),
          _buildRescheduleSimulationTab(),
        ],
      ),
    );
  }

  Widget _buildEventVerificationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: appCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enjin Pengesahan Acara Jualan Rahmah (KPDN)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sistem memadankan nama, lokasi, tarikh, negeri dan status secara berwajaran (100 markah).',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _eventNameController,
                decoration: const InputDecoration(labelText: 'Nama Acara / Program'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _eventOrganiserController,
                decoration: const InputDecoration(labelText: 'Penganjur'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _eventAddressController,
                decoration: const InputDecoration(labelText: 'Lokasi / Alamat'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _eventStateController,
                      decoration: const InputDecoration(labelText: 'Negeri'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _eventDistrictController,
                      decoration: const InputDecoration(labelText: 'Daerah'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tarikh Pelaksanaan:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormat('d MMMM yyyy').format(_eventDate)),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('Pilih'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2028),
                    );
                    if (picked != null) setState(() => _eventDate = picked);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isTestingEngine ? null : _runEventVerification,
                      icon: _isTestingEngine
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.policy_outlined),
                      label: const Text('Uji Verifikasi Rasmi'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveEvent,
                      icon: const Icon(Icons.publish),
                      label: const Text('Sahkan & Terbit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantVerificationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: appCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pengesahan Rakan Dagang MyKasih / SARA',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Menyemak kesahihan rakan niaga berdaftar di bawah Yayasan MyKasih.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _merchantNameController,
                decoration: const InputDecoration(labelText: 'Nama Peniaga / Premis'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _merchantAddressController,
                decoration: const InputDecoration(labelText: 'Alamat Penuh'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isTestingEngine ? null : _runMerchantVerification,
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Semak Pangkalan Data MyKasih'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRescheduleSimulationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: appCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ujian Level 3: Pengesanan Perubahan Jadual & Notifikasi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Simulasi jika pihak KPDN menunda tarikh acara. Sistem akan mengesan percanggahan tarikh dan menghantar amaran secara automatik kepada semua pengguna.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tarikh Baharu KPDN:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormat('d MMMM yyyy').format(_rescheduleNewDate)),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: const Text('Ubah Tarikh'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _rescheduleNewDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2028),
                    );
                    if (picked != null) setState(() => _rescheduleNewDate = picked);
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final newDateStr =
                        DateFormat('yyyy-MM-dd').format(_rescheduleNewDate);
                    setState(() => _rescheduleFeedback =
                        'Memproses pengesanan perubahan & penyiaran notifikasi...');
                    // Simulate
                    await Future.delayed(const Duration(milliseconds: 600));
                    setState(() {
                      _rescheduleFeedback =
                          '✅ Berjaya! Jadual telah dikemaskini kepada $newDateStr dan notifikasi "⚠️ Kemaskini Jadual Acara" telah disiarkan kepada pengguna.';
                    });
                  },
                  icon: const Icon(Icons.campaign),
                  label: const Text('Simulasi Kemaskini Jadual & Siar Notifikasi'),
                ),
              ),
              if (_rescheduleFeedback != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    _rescheduleFeedback!,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
