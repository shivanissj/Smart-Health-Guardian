import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

/// Colored status pill: GOOD / NEEDS ATTENTION / EMERGENCY
class StatusPill extends StatelessWidget {
  final HealthStatus status;
  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color fg;
    late final Color bg;
    late final String label;
    switch (status) {
      case HealthStatus.good:
        fg = AppColors.tealDark;
        bg = AppColors.tealTint;
        label = 'GOOD';
        break;
      case HealthStatus.attention:
        fg = const Color(0xFF9A7517);
        bg = AppColors.warnTint;
        label = 'NEEDS ATTENTION';
        break;
      case HealthStatus.emergency:
        fg = AppColors.danger;
        bg = AppColors.dangerTint;
        label = 'EMERGENCY';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

/// Small labeled stat block, e.g. "Heart Rate  78 BPM"
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  const StatTile({super.key, required this.label, required this.value, required this.icon, this.accent});

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.teal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.grey500, fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashboard grid card used on Home screen (Pair Watch, Health Dashboard, etc.)
class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color? backgroundColor;
  final VoidCallback onTap;
  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = AppColors.teal,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.white;
    final textColor = backgroundColor != null ? AppColors.white : AppColors.black;
    final subtitleColor = backgroundColor != null ? AppColors.white.withOpacity(0.85) : AppColors.grey700;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: backgroundColor != null ? null : Border.all(color: AppColors.grey100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: backgroundColor != null ? accent.withOpacity(0.25) : accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const Spacer(),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: textColor)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Section title used throughout detail screens
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grey500)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SosButton extends StatelessWidget {
  final VoidCallback onPressed;
  const SosButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.sos_rounded, size: 20),
      label: const Text('SOS'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: AppColors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
    );
  }
}
