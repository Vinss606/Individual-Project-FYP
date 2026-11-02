import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mykasih_header.dart';
import '../widgets/location_setup_card.dart';
import '../widgets/verification_badge.dart';

class MyKasihScreen extends StatefulWidget {
  const MyKasihScreen({
    super.key,
    required this.apiService,
    required this.user,
    required this.onLogout,
    this.onOpenNotifications,
    this.isAdmin = false,
    this.onToggleAdmin,
  });

  final ApiService apiService;
  final AppUser user;
  final VoidCallback onLogout;
  final VoidCallback? onOpenNotifications;
  final bool isAdmin;
  final VoidCallback? onToggleAdmin;

  @override
  State<MyKasihScreen> createState() => _MyKasihScreenState();
}

enum _ViewState { needLocation, loading, loaded, error }

class _MyKasihScreenState extends State<MyKasihScreen> {
  _ViewState _state = _ViewState.needLocation;
  List<MyKasihLocation> _locations = [];
  String _areaLabel = '';
  String? _errorMessage;
  final _searchController = TextEditingController();
  String _statusFilter = 'ALL'; // ALL, VERIFIED, PENDING_REVIEW

  Future<void> _useGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Sila hidupkan perkhidmatan lokasi (GPS).');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Kebenaran akses lokasi peranti telah ditolak.');
      }
      final pos = await Geolocator.getCurrentPosition();
      await _loadLocations(pos.latitude, pos.longitude, 'Lokasi Semasa (GPS)');
    } catch (e) {
      setState(() {
        _state = _ViewState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _searchArea(String area) async {
    if (area.trim().isEmpty) return;
    // Defaulting to Penang / Butterworth coordinates for prototype demo
    await _loadLocations(5.3991, 100.3638, area);
  }

  Future<void> _loadLocations(double lat, double lng, String areaLabel) async {
    setState(() {
      _state = _ViewState.loading;
      _areaLabel = areaLabel;
    });
    try {
      final results = await widget.apiService.getMyKasihLocations(
        lat: lat,
        lng: lng,
        statusFilter: _statusFilter == 'ALL' ? null : _statusFilter,
      );
      setState(() {
        _locations = results;
        _state = _ViewState.loaded;
      });
    } catch (e) {
      setState(() {
        _state = _ViewState.error;
        _errorMessage = 'Gagal memuatkan lokasi MyKasih. Sila cuba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (_state == _ViewState.needLocation)
            MyKasihHeader(
              userName: widget.user.name,
              onLogout: widget.onLogout,
              onOpenNotifications: widget.onOpenNotifications,
              isAdmin: widget.isAdmin,
              onToggleAdmin: widget.onToggleAdmin,
            )
          else
            MyKasihHeader(
              userName: widget.user.name,
              onLogout: widget.onLogout,
              onOpenNotifications: widget.onOpenNotifications,
              isAdmin: widget.isAdmin,
              onToggleAdmin: widget.onToggleAdmin,
              child: _buildLoadedHeaderContent(),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildLoadedHeaderContent() {
    final today = _locations.where((l) =>
        l.date.year == DateTime.now().year &&
        l.date.month == DateTime.now().month &&
        l.date.day == DateTime.now().day).length;
    final nearest = _locations.isEmpty
        ? null
        : (List<MyKasihLocation>.from(_locations)
              ..sort((a, b) =>
                  (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0)))
            .first;
    final quotaLeft =
        _locations.fold<int>(0, (sum, l) => sum + l.quotaRemaining);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text('Pengagihan MyKasih / SARA',
                style: TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Dalam 30km',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            children: [
              TextSpan(text: '${_locations.length} lokasi dalam 30km dari '),
              TextSpan(
                text: _areaLabel,
                style: const TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Cari peniaga atau alamat...',
            prefixIcon: Icon(Icons.search, size: 18),
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: Icons.calendar_today,
                value: '$today',
                label: 'Buka Hari Ini',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                icon: Icons.location_on,
                value: nearest?.distanceKm != null
                    ? '${nearest!.distanceKm!.toStringAsFixed(1)}km'
                    : '-',
                label: 'Paling Hampir',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                icon: Icons.groups,
                value: '$quotaLeft',
                label: 'Kuota Baki',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ViewState.needLocation:
        return LocationSetupCard(
          targetLabel: 'Pusat Pengagihan MyKasih / Rakan Niaga SARA',
          onUseGps: _useGps,
          onSearchArea: _searchArea,
        );
      case _ViewState.loading:
        return const Center(child: CircularProgressIndicator());
      case _ViewState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
                const SizedBox(height: 12),
                Text(_errorMessage ?? 'Ralat berlaku',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() => _state = _ViewState.needLocation),
                  child: const Text('Cuba Lagi'),
                ),
              ],
            ),
          ),
        );
      case _ViewState.loaded:
        final query = _searchController.text.toLowerCase();
        final filtered = query.isEmpty
            ? _locations
            : _locations
                .where((l) =>
                    l.name.toLowerCase().contains(query) ||
                    l.address.toLowerCase().contains(query))
                .toList();

        return RefreshIndicator(
          onRefresh: () => _loadLocations(5.3991, 100.3638, _areaLabel),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Filter chips for verification status
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Semua Status',
                      selected: _statusFilter == 'ALL',
                      onTap: () {
                        setState(() => _statusFilter = 'ALL');
                        _loadLocations(5.3991, 100.3638, _areaLabel);
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '🟢 Disahkan Rasmi',
                      selected: _statusFilter == 'VERIFIED',
                      onTap: () {
                        setState(() => _statusFilter = 'VERIFIED');
                        _loadLocations(5.3991, 100.3638, _areaLabel);
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '🟡 Dalam Semakan',
                      selected: _statusFilter == 'PENDING_REVIEW',
                      onTap: () {
                        setState(() => _statusFilter = 'PENDING_REVIEW');
                        _loadLocations(5.3991, 100.3638, _areaLabel);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Tiada lokasi pengagihan dijumpai.')),
                )
              else
                ...filtered.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LocationCard(location: l),
                    )),
            ],
          ),
        );
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

class _LocationCard extends StatefulWidget {
  const _LocationCard({required this.location});
  final MyKasihLocation location;

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l = widget.location;
    final isUpcoming = l.date.isAfter(DateTime.now());
    final dateFmt = DateFormat('d MMM yyyy');

    return Container(
      decoration: appCardDecoration().copyWith(
        border: Border.all(color: AppColors.primaryLight, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VerificationBadge(
                status: l.verificationStatus,
                sourceName: l.sourceName,
                lastVerified: l.lastVerified,
                sourceUrl: l.sourceUrl,
                compact: true,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE7EC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '📍 ${l.distanceKm?.toStringAsFixed(1) ?? '-'} km',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFDB2777), fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(l.address,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Sumber: ${l.sourceName} • Disemak: ${l.lastVerified}',
                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(dateFmt.format(l.date), style: const TextStyle(fontSize: 12.5)),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('${l.startTime} - ${l.endTime}',
                    style: const TextStyle(fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kuota Baki Bantuan',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                Text('${l.quotaRemaining}/${l.quotaTotal}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: l.quotaTotal == 0 ? 0 : l.quotaRemaining / l.quotaTotal,
                minHeight: 6,
                backgroundColor: AppColors.primaryLight,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),
            const Text('BARANGAN ASAS YANG DIAGIHKAN:',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: l.items
                  .map((item) => Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(item,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primary)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        ApiService.launchGoogleMaps(l.latitude, l.longitude),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text('Google Maps', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        ApiService.launchWaze(l.latitude, l.longitude),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B0FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.explore_outlined, size: 16),
                    label: const Text('Waze', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
