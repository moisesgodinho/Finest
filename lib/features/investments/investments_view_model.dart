import 'package:flutter_riverpod/flutter_riverpod.dart';

class InvestmentsState {
  const InvestmentsState({
    this.totalInvestedCents = 320000,
    this.monthlyInvestedCents = 60000,
  });

  final int totalInvestedCents;
  final int monthlyInvestedCents;
}

class InvestmentsViewModel extends StateNotifier<InvestmentsState> {
  InvestmentsViewModel() : super(const InvestmentsState());
}

final investmentsViewModelProvider =
    StateNotifierProvider<InvestmentsViewModel, InvestmentsState>((ref) {
  return InvestmentsViewModel();
});
