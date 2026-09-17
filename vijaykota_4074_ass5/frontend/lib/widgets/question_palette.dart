import 'package:flutter/material.dart';
import '../providers/attempt_provider.dart';
import '../theme/app_theme.dart';

class QuestionPalette extends StatelessWidget {
  final int totalQuestions;
  final int currentIndex;
  final Function(int) onSelectQuestion;
  final QuestionPaletteState Function(int) getState;

  const QuestionPalette({
    super.key,
    required this.totalQuestions,
    required this.currentIndex,
    required this.onSelectQuestion,
    required this.getState,
  });

  Color _getColorForState(QuestionPaletteState state) {
    switch (state) {
      case QuestionPaletteState.answered:
        return AppTheme.statusGreen;
      case QuestionPaletteState.visitedUnanswered:
        return AppTheme.statusRed;
      case QuestionPaletteState.markedForReview:
        return AppTheme.statusPurple;
      case QuestionPaletteState.notVisited:
        return AppTheme.statusGray.withValues(alpha: 0.35);
    }
  }

  Color _getTextColorForState(QuestionPaletteState state) {
    switch (state) {
      case QuestionPaletteState.answered:
      case QuestionPaletteState.visitedUnanswered:
      case QuestionPaletteState.markedForReview:
        return Colors.white;
      case QuestionPaletteState.notVisited:
        return AppTheme.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Question Palette',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem(AppTheme.statusGreen, 'Answered'),
              _buildLegendItem(AppTheme.statusRed, 'Visited'),
              _buildLegendItem(AppTheme.statusPurple, 'Review'),
              _buildLegendItem(AppTheme.statusGray.withValues(alpha: 0.35), 'Not Visited', textColor: AppTheme.textSecondary),
            ],
          ),
        ),

        const Divider(height: 24),

        // Grid of questions
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              itemCount: totalQuestions,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final state = getState(index);
                final isCurrent = index == currentIndex;
                final bgColor = _getColorForState(state);
                final textColor = _getTextColorForState(state);

                return InkWell(
                  onTap: () => onSelectQuestion(index),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: isCurrent
                          ? Border.all(color: AppTheme.royalBlue, width: 2.5)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, {Color textColor = AppTheme.textPrimary}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
