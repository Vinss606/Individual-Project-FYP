import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The "Tetapkan Lokasi Anda" card shown before either the MyKasih or
/// the Jualan Rahmah list is loaded. [targetLabel] is what we're
/// searching for, e.g. "Lokasi Pengagihan MyKasih" or
/// "Jualan Rahmah Madani".
class LocationSetupCard extends StatefulWidget {
  const LocationSetupCard({
    super.key,
    required this.targetLabel,
    required this.onUseGps,
    required this.onSearchArea,
  });

  final String targetLabel;
  final Future<void> Function() onUseGps;
  final void Function(String area) onSearchArea;

  static const popularAreas = [
    'Georgetown',
    'Air Itam',
    'Bayan Lepas',
    'Jelutong',
    'Butterworth',
    'Bukit Mertajam',
    'Batu Ferringhi',
  ];

  @override
  State<LocationSetupCard> createState() => _LocationSetupCardState();
}

class _LocationSetupCardState extends State<LocationSetupCard> {
  final _controller = TextEditingController();
  bool _loadingGps = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleGps() async {
    setState(() => _loadingGps = true);
    try {
      await widget.onUseGps();
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: appCardDecoration(radius: 20),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on,
                      color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tetapkan Lokasi Anda',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13, height: 1.4),
                    children: [
                      const TextSpan(text: 'Kami akan mencari '),
                      TextSpan(
                        text: widget.targetLabel,
                        style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' dalam lingkungan '),
                      const TextSpan(
                        text: '30 km',
                        style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' dari lokasi anda.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Masukkan poskod atau nama kawasan',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Cth: 10050 atau Batu Ferringhi',
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                        onSubmitted: widget.onSearchArea,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => widget.onSearchArea(_controller.text),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                      child: const Text('Cari'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Kawasan popular:',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LocationSetupCard.popularAreas
                      .map((area) => ActionChip(
                            label: Text(area,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.primary)),
                            backgroundColor: AppColors.primaryLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide.none,
                            ),
                            onPressed: () => widget.onSearchArea(area),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('atau',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadingGps ? null : _handleGps,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _loadingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Guna GPS Peranti',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
                      children: [
                        TextSpan(text: 'Lokasi anda '),
                        TextSpan(
                            text: 'tidak disimpan',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(
                            text:
                                '. Ia hanya digunakan untuk mengira jarak ke lokasi terdekat dalam sesi ini sahaja.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
