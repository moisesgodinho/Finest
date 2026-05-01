import 'package:flutter_riverpod/flutter_riverpod.dart';

class PetState {
  const PetState({
    this.petName = 'Finny',
    this.level = 3,
    this.xp = 420,
    this.currentStage = 'Broto investidor',
    this.totalInvestedCents = 320000,
  });

  final String petName;
  final int level;
  final int xp;
  final String currentStage;
  final int totalInvestedCents;
}

class PetViewModel extends StateNotifier<PetState> {
  PetViewModel() : super(const PetState());
}

final petViewModelProvider = StateNotifierProvider<PetViewModel, PetState>((
  ref,
) {
  return PetViewModel();
});
