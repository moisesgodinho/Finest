import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionsState {
  const TransactionsState({
    this.selectedType = 'todos',
  });

  final String selectedType;
}

class TransactionsViewModel extends StateNotifier<TransactionsState> {
  TransactionsViewModel() : super(const TransactionsState());

  void selectType(String type) {
    state = TransactionsState(selectedType: type);
  }
}

final transactionsViewModelProvider =
    StateNotifierProvider<TransactionsViewModel, TransactionsState>((ref) {
  return TransactionsViewModel();
});
