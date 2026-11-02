import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mykasih_header.dart';
import '../widgets/location_setup_card.dart';
import '../widgets/verification_badge.dart';

class JualanRahmahScreen extends StatefulWidget {
  const JualanRahmahScreen({
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
  State<JualanRahmahScreen> createState() => _JualanRahmahScreenState();
}

enum _ViewState { needLocation, loading, loaded, error }

class _JualanRahmahScreenState extends State<JualanRahmahScreen> {
  _ViewState _state = _ViewState.needLocation;
  List<JualanRahmahListing> _listings = [];
  String _areaLabel = '';
  String? _errorMessage;
  final _searchController = TextEditingController();
  String _statusFilter = 'ALL';

  Future<void> _useGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Sila hidupkan perkhidmatan lokasi.');
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
      await _loadListings(pos.latitude, pos.longitude, 'Lokasi Semasa (GPS)');
    } catch (e) {
      setState(() {
        _state = _ViewState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _searchArea(String area) async {
    if (area.trim().isEmpty) return;
    await _loadListings(5.3991, 100.3638, area);
  }

  Future<void> _loadListings(double lat, double lng, String areaLabel) async {
    setState(() {
      _state = _ViewState.loading;
      _areaLabel = areaLabel;
    });
    try {
      final results = await widget.apiService.getJualanRahmahListings(
        lat: lat,
        lng: lng,
        statusFilter: _statusFilter == 'ALL' ? null : _statusFilter,
      );
      setState(() {
        _listings = results;
        _state = _ViewState.loaded;
      });
    } catch (e) {
      setState(() {
        _state = _ViewState.error;
        _errorMessage = 'Gagal memuatkan jualan. Sila cuba lagi.';
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
          if (_state == _ViewState.loaded) _buildPriceControlBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildPriceControlBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sell_outlined, size: 18, color: Color(0xFFB07A15)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                    color: Color(0xFF6B4E10), fontSize: 12.5, height: 1.4),
                children: [
                  TextSpan(
                      text: 'Harga Kawalan Rasmi: ',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                      text:
                          'Semua barangan disahkan dijual di bawah harga pasaran (diskaun 10% - 30%). Had 1 unit setiap item bagi setiap keluarga.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedHeaderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text('Jualan Rahmah Madani (PJRM)',
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
              TextSpan(text: '${_listings.length} jualan dalam 30km dari '),
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
            hintText: 'Cari lokasi atau nama program...',
            prefixIcon: Icon(Icons.search, size: 18),
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ViewState.needLocation:
        return LocationSetupCard(
          targetLabel: 'Program Jualan Rahmah Madani (KPDN)',
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
                Text(_errorMessage ?? 'Ralat berlaku', textAlign: TextAlign.center),
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
            ? _listings
            : _listings
                .where((l) =>
                    l.name.toLowerCase().contains(query) ||
                    l.address.toLowerCase().contains(query) ||
                    l.organiser.toLowerCase().contains(query))
                .toList();

        return RefreshIndicator(
          onRefresh: () => _loadListings(5.3991, 100.3638, _areaLabel),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              // Filter chips for verification status
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Semua',
                      selected: _statusFilter == 'ALL',
                      onTap: () {
                        setState(() => _statusFilter = 'ALL');
                        _loadListings(5.3991, 100.3638, _areaLabel);
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '🟢 Disahkan Rasmi',
                      selected: _statusFilter == 'VERIFIED',
                      onTap: () {
                        setState(() => _statusFilter = 'VERIFIED');
                        _loadListings(5.3991, 100.3638, _areaLabel);
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '🟡 Dalam Semakan',
                      selected: _statusFilter == 'PENDING_REVIEW',
                      onTap: () {
                        setState(() => _statusFilter = 'PENDING_REVIEW');
                        _loadListings(5.3991, 100.3638, _areaLabel);
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '⚫ Telah Berakhir',
                      selected: _statusFilter == 'EXPIRED',
                      onTap: () {
                        setState(() => _statusFilter = 'EXPIRED');
                        _loadListings(5.3991, 100.3638, _areaLabel);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Tiada jualan dijumpai.')),
                )
              else
                ...filtered.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ListingCard(listing: l),
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

class _ListingCard extends StatefulWidget {
  const _ListingCard({required this.listing});
  final JualanRahmahListing listing;

  @override
  State<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<_ListingCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final dayFmt = DateFormat('EEEE, d MMM yyyy', 'ms');
    final isExpired = l.isExpired;

    return Container(
      decoration: appCardDecoration().copyWith(
        color: isExpired ? const Color(0xFFFAFAFA) : Colors.white,
        border: Border.all(
          color: isExpired ? const Color(0xFFE5E7EB) : AppColors.primaryLight,
          width: 1.5,
        ),
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
                matchScore: l.matchScore,
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
          if (l.rescheduled) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_calendar, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '⚠️ Jadual telah dikemaskini mengikut data rasmi KPDN.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(l.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isExpired ? AppColors.textMuted : AppColors.textDark,
              )),
          const SizedBox(height: 2),
          Text(l.organiser,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Sumber: ${l.sourceName} • Semakan: ${l.lastVerified}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.calendar_today, text: dayFmt.format(l.date)),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.access_time, text: '${l.startTime} - ${l.endTime}'),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.location_on_outlined, text: l.address),
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.groups_outlined,
                text: 'Sasaran Penerima: ${l.targetFamilies} keluarga'),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('SENARAI HARGA KAWALAN:',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold)),
                Text('PENJIMATAN',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ...l.priceList.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              'Harga Pasaran: RM${p.marketPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  decoration: TextDecoration.lineThrough),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('RM${p.controlledPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Jimat RM${p.savings.toStringAsFixed(2)} (-${p.discountPercent.toStringAsFixed(0)}%)',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
      ],
    );
  }
}
