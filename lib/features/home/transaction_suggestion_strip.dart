import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/transaction_name_suggestion.dart';

class TransactionSuggestionStrip extends StatelessWidget {
  const TransactionSuggestionStrip({
    required this.suggestions,
    required this.onSelected,
    this.label = 'Usar dados de',
    this.detailBuilder,
    super.key,
  });

  final List<TransactionNameSuggestion> suggestions;
  final ValueChanged<TransactionNameSuggestion> onSelected;
  final String label;
  final String Function(TransactionNameSuggestion suggestion)? detailBuilder;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in suggestions)
              ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 18),
                label: Text(
                  _labelFor(suggestion),
                  overflow: TextOverflow.ellipsis,
                ),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
                onPressed: () => onSelected(suggestion),
              ),
          ],
        ),
      ],
    );
  }

  String _labelFor(TransactionNameSuggestion suggestion) {
    final detail = detailBuilder?.call(suggestion);
    if (detail == null || detail.isEmpty) {
      return suggestion.description;
    }
    return '${suggestion.description} • $detail';
  }
}
