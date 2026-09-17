import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    final lower = status.toLowerCase();

    if (lower == 'active' || lower == 'pass' || lower == 'published') {
      bgColor = AppTheme.statusGreen.withValues(alpha: 0.15);
      textColor = AppTheme.statusGreen;
    } else if (lower == 'fail' || lower == 'expired') {
      bgColor = AppTheme.statusRed.withValues(alpha: 0.15);
      textColor = AppTheme.statusRed;
    } else if (lower == 'upcoming') {
      bgColor = AppTheme.statusAmber.withValues(alpha: 0.15);
      textColor = AppTheme.statusAmber;
    } else if (lower == 'completed') {
      bgColor = AppTheme.royalBlue.withValues(alpha: 0.15);
      textColor = AppTheme.royalBlue;
    } else {
      bgColor = AppTheme.statusGray.withValues(alpha: 0.2);
      textColor = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
