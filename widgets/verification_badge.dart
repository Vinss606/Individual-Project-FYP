import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Interactive Verification Status Badge matching Section 6 & 9 of DPP specification:
/// 🟢 VERIFIED (Disahkan Rasmi)
/// 🟡 PENDING_REVIEW (Dalam Semakan)
/// 🔴 NOT_VERIFIED (Tidak Sah)
/// ⚫ EXPIRED (Telah Berakhir)
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({
    super.key,
    required this.status,
    required this.sourceName,
    required this.lastVerified,
    this.sourceUrl,
    this.matchScore,
    this.compact = false,
  });

  final String status;
  final String sourceName;
  final String lastVerified;
  final String? sourceUrl;
  final double? matchScore;
  final bool compact;

  Future<void> _openOfficialSource() async {
    try {
      var url = sourceUrl ?? 'https://pjrm.kpdn.gov.my/';
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showDetailsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  VerificationStatusHelper.getBadgeIcon(status),
                  color: VerificationStatusHelper.getBadgeColor(status),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        VerificationStatusHelper.getLabel(status),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Enjin Pengesahan Sumber Rasmi (Level 1 - 3)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.account_balance,
              label: 'Sumber Rasmi:',
              value: sourceName,
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.history,
              label: 'Tarikh Terakhir Disemak:',
              value: lastVerified,
            ),
            if (sourceUrl != null) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.link,
                label: 'Pautan Rasmi:',
                value: sourceUrl!,
              ),
            ],
            if (matchScore != null) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.score,
                label: 'Skor Padanan Algoritma:',
                value: '${matchScore!.toStringAsFixed(1)} / 100',
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VerificationStatusHelper.getBadgeBgColor(status),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _getStatusExplanation(status),
                style: TextStyle(
                  fontSize: 12.5,
                  color: VerificationStatusHelper.getBadgeColor(status),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (sourceUrl != null && sourceUrl!.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openOfficialSource,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Buka Portal Rasmi', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Faham'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusExplanation(String st) {
    switch (st.toUpperCase()) {
      case VerificationStatusHelper.verified:
        return '🟢 Maklumat disahkan sepadan dengan pangkalan data rasmi kerajaan (KPDN https://pjrm.kpdn.gov.my/ atau Yayasan MyKasih https://www.mykasih.com.my/ms/about-us/merchant-partners/).';
      case VerificationStatusHelper.pending:
        return '🟡 Maklumat belum dapat dipadankan sepenuhnya secara automatik dan sedang menunggu semakan lanjut pentadbir.';
      case VerificationStatusHelper.notVerified:
        return '🔴 Maklumat bercanggah atau tidak ditemui dalam rekod rasmi penganjur.';
      case VerificationStatusHelper.expired:
        return '⚫ Acara ini telah melepasi tarikh pelaksanaan dan program telah berakhir secara rasmi.';
      default:
        return 'Status pengesahan rekod bantuan.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = VerificationStatusHelper.getBadgeColor(status);
    final bg = VerificationStatusHelper.getBadgeBgColor(status);
    final label = VerificationStatusHelper.getLabel(status);
    final icon = VerificationStatusHelper.getBadgeIcon(status);

    return InkWell(
      onTap: () => _showDetailsDialog(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}
