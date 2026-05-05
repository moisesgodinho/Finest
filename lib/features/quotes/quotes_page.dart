import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/currency/app_currency.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/section_card.dart';
import 'quotes_view_model.dart';

class QuotesPage extends ConsumerWidget {
  const QuotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quotesViewModelProvider);
    final viewModel = ref.read(quotesViewModelProvider.notifier);
    final selectedCurrency = AppCurrencies.byCode(state.selectedCurrencyCode);

    ref.listen(quotesViewModelProvider.select((state) => state.errorMessage), (
      previous,
      next,
    ) {
      if (next == null || next == previous) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cotação offline: $next')),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotações'),
        actions: [
          IconButton(
            onPressed: state.isRefreshing ? null : viewModel.refreshNow,
            tooltip: 'Atualizar cotações',
            icon: state.isRefreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: viewModel.refreshNow,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              _QuotesHeaderCard(
                selectedCurrency: selectedCurrency,
                lastFetchedAt: state.lastFetchedAt,
                isLoading: state.isLoading,
              ),
              const SizedBox(height: 14),
              if (state.isLoading && state.quotes.isEmpty)
                const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Moedas monitoradas',
                child: state.quotes.isEmpty && !state.isLoading
                    ? const _EmptyQuotes()
                    : Column(
                        children: [
                          for (final quote in state.quotes)
                            _QuoteTile(
                              quote: quote,
                              selectedCurrency: selectedCurrency,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              const _QuotesInfoCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotesHeaderCard extends StatelessWidget {
  const _QuotesHeaderCard({
    required this.selectedCurrency,
    required this.lastFetchedAt,
    required this.isLoading,
  });

  final AppCurrency selectedCurrency;
  final DateTime? lastFetchedAt;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: colors.primaryLight.withValues(alpha: 0.22),
              foregroundColor: Colors.white,
              child: const Icon(Icons.currency_exchange_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Câmbio salvo no aparelho',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLoading && lastFetchedAt == null
                        ? 'Buscando cotações...'
                        : 'Base visual: ${selectedCurrency.code} • ${_relativeTime(lastFetchedAt)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
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

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({
    required this.quote,
    required this.selectedCurrency,
  });

  final QuoteItem quote;
  final AppCurrency selectedCurrency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasRate = quote.rateToBrl > 0;
    final showSelectedConversion =
        selectedCurrency.code != AppCurrencies.defaultCode && hasRate;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.accentSoft,
            foregroundColor: colors.primary,
            child: Text(
              quote.currency.code.characters.take(2).toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${quote.currency.code} - ${quote.currency.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  hasRate
                      ? '1 ${quote.currency.code} = ${_formatCurrency(quote.rateToBrl, AppCurrencies.byCode(AppCurrencies.defaultCode))}'
                      : 'Cotação ainda não salva',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                showSelectedConversion
                    ? _formatCurrency(
                        quote.rateToSelectedCurrency,
                        selectedCurrency,
                      )
                    : hasRate
                        ? _formatCurrency(
                            quote.rateToBrl,
                            AppCurrencies.byCode(AppCurrencies.defaultCode),
                          )
                        : '--',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color:
                          hasRate ? colors.textPrimary : colors.textSecondary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                showSelectedConversion
                    ? 'em ${selectedCurrency.code}'
                    : _shortDate(quote.fetchedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotesInfoCard extends StatelessWidget {
  const _QuotesInfoCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'O Finest busca novas cotações no máximo uma vez por hora e usa o último valor local quando estiver offline. Transferências entre moedas usam a cotação salva ou recém-buscada.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyQuotes extends StatelessWidget {
  const _EmptyQuotes();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: colors.textSecondary,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            'Nenhuma cotação local ainda.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Toque em atualizar quando estiver conectado.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _formatCurrency(double amount, AppCurrency currency) {
  final formatter = NumberFormat.currency(
    locale: currency.locale,
    symbol: currency.symbol,
    decimalDigits: amount.abs() >= 1 ? 4 : 6,
  );
  return formatter.format(amount);
}

String _relativeTime(DateTime? date) {
  if (date == null || date.millisecondsSinceEpoch == 0) {
    return 'sem cotação local';
  }

  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) {
    return 'atualizado agora';
  }
  if (diff.inHours < 1) {
    return 'há ${diff.inMinutes} min';
  }
  if (diff.inDays < 1) {
    return 'há ${diff.inHours} h';
  }
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _shortDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) {
    return 'sem data';
  }
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
