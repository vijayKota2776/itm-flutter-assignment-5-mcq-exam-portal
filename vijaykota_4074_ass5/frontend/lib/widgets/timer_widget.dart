import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TimerWidget extends StatelessWidget {
  final int remainingSeconds;

  const TimerWidget({super.key, required this.remainingSeconds});

  @override
  Widget build(BuildContext context) {
    final int minutes = remainingSeconds ~/ 60;
    final int seconds = remainingSeconds % 60;
    final String formattedTime =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final bool isLowTime = remainingSeconds > 0 && remainingSeconds <= 300; // < 5 mins

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isLowTime ? AppTheme.statusRed.withValues(alpha: 0.12) : AppTheme.royalBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLowTime ? AppTheme.statusRed : AppTheme.royalBlue.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: isLowTime ? AppTheme.statusRed : AppTheme.royalBlue,
          ),
          const SizedBox(width: 6),
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: isLowTime ? AppTheme.statusRed : AppTheme.royalBlue,
            ),
          ),
        ],
      ),
    );
  }
}
