import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/section_card.dart';
import 'transactions_view_model.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionsViewModelProvider);
    final viewModel = ref.read(transactionsViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamentos'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            SectionCard(
              title: 'Novo lançamento',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'todos',
                        label: Text('Todos'),
                        icon: Icon(Icons.list_alt_rounded),
                      ),
                      ButtonSegment(
                        value: 'receita',
                        label: Text('Receita'),
                        icon: Icon(Icons.arrow_downward_rounded),
                      ),
                      ButtonSegment(
                        value: 'despesa',
                        label: Text('Despesa'),
                        icon: Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                    selected: {state.selectedType},
                    onSelectionChanged: (selection) {
                      viewModel.selectType(selection.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A estrutura está pronta para ligar formulário, categorias, contas, cartões e recorrência ao Drift.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
