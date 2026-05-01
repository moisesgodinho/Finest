import 'package:flutter_riverpod/flutter_riverpod.dart';

class PetState {
  const PetState({
    this.petName = 'Finny',
    this.level = 1,
    this.xp = 180,
    this.xpToNextLevel = 500,
    this.totalInvestedCents = 320000,
    this.monthlyContributionCents = 60000,
    this.trackedDays = 6,
    this.contributionStreakMonths = 1,
    this.savingsRate = 0.08,
    this.runwayMonths = 0.7,
    this.hasEarlyContributionBuff = false,
  });

  final String petName;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int totalInvestedCents;
  final int monthlyContributionCents;
  final int trackedDays;
  final int contributionStreakMonths;
  final double savingsRate;
  final double runwayMonths;
  final bool hasEarlyContributionBuff;

  PetEvolutionLevel get currentLevel {
    return petEvolutionLevels.firstWhere(
      (stage) => stage.level == level,
      orElse: () => petEvolutionLevels.first,
    );
  }

  double get progressToNextLevel {
    if (xpToNextLevel <= 0) {
      return 0;
    }
    return (xp / xpToNextLevel).clamp(0.0, 1.0).toDouble();
  }

  int get remainingXp => (xpToNextLevel - xp).clamp(0, xpToNextLevel);

  double get trackingProgress => (trackedDays / 15).clamp(0.0, 1.0).toDouble();

  double get consistencyProgress {
    return (contributionStreakMonths / 3).clamp(0.0, 1.0).toDouble();
  }

  double get runwayProgress => (runwayMonths / 1).clamp(0.0, 1.0).toDouble();

  double get energyProgress => (savingsRate / 0.10).clamp(0.0, 1.0).toDouble();
}

class PetEvolutionLevel {
  const PetEvolutionLevel({
    required this.level,
    required this.title,
    required this.trigger,
    required this.visual,
    required this.concept,
  });

  final int level;
  final String title;
  final String trigger;
  final String visual;
  final String concept;
}

class PetMechanic {
  const PetMechanic({
    required this.title,
    required this.gameFunction,
    required this.financialMeaning,
  });

  final String title;
  final String gameFunction;
  final String financialMeaning;
}

class PetViewModel extends StateNotifier<PetState> {
  PetViewModel() : super(const PetState());
}

final petViewModelProvider = StateNotifierProvider<PetViewModel, PetState>((
  ref,
) {
  return PetViewModel();
});

const petEvolutionLevels = [
  PetEvolutionLevel(
    level: 1,
    title: 'O Desperto',
    trigger: 'Registrar todas as despesas por 15 dias seguidos.',
    visual: 'O ovo começa a rachar e ganha olhinhos.',
    concept: 'O primeiro passo é saber para onde o dinheiro vai.',
  ),
  PetEvolutionLevel(
    level: 2,
    title: 'O Poupador Iniciante',
    trigger: 'Primeiro mês economizando qualquer valor.',
    visual: 'O bichinho nasce pequeno e desajeitado.',
    concept: 'Romper a inércia e começar o hábito.',
  ),
  PetEvolutionLevel(
    level: 3,
    title: 'O Sobrevivente',
    trigger: 'Acumular 1 mês de custo de vida.',
    visual: 'Ele ganha uma mochila de provisões.',
    concept: 'Garantir os primeiros 30 dias de segurança.',
  ),
  PetEvolutionLevel(
    level: 4,
    title: 'O Guardião da Rotina',
    trigger: 'Investir por 3 meses consecutivos.',
    visual: 'Ele ganha um escudo ou aura de proteção.',
    concept: 'Premiar repetição do hábito, não valor alto.',
  ),
  PetEvolutionLevel(
    level: 5,
    title: 'O Atleta Financeiro',
    trigger: 'Economizar 10% ou mais da renda mensal.',
    visual: 'Ele fica mais atlético e ativo.',
    concept: 'Subir o nível de esforço e otimização.',
  ),
  PetEvolutionLevel(
    level: 6,
    title: 'O Construtor',
    trigger: 'Acumular 3 meses de custo de vida.',
    visual: 'O cenário evolui para uma pequena cabana.',
    concept: 'Construir segurança intermediária.',
  ),
  PetEvolutionLevel(
    level: 7,
    title: 'O Estrategista',
    trigger: 'Manter 6 meses seguidos de aportes.',
    visual: 'Ele ganha acessórios de mestre.',
    concept: 'Transformar investimento em processo automático.',
  ),
  PetEvolutionLevel(
    level: 8,
    title: 'O Caçador de Eficiência',
    trigger: 'Economizar 20% ou mais da renda por 2 meses.',
    visual: 'Ele ganha itens de alta performance.',
    concept: 'Viver bem usando menos do que ganha.',
  ),
  PetEvolutionLevel(
    level: 9,
    title: 'O Barão da Segurança',
    trigger: 'Acumular 6 meses de custo de vida.',
    visual: 'A cabana vira um castelo.',
    concept: 'Paz de espírito para enfrentar crises.',
  ),
  PetEvolutionLevel(
    level: 10,
    title: 'O Eterno',
    trigger: 'Manter 12 meses de consistência e taxa acima de 15%.',
    visual: 'Ele se torna guardião do ecossistema.',
    concept: 'O hábito está enraizado no dia a dia.',
  ),
];

const petMechanics = [
  PetMechanic(
    title: 'Comida',
    gameFunction: 'Aporte mensal',
    financialMeaning: 'Colocar dinheiro em qualquer investimento.',
  ),
  PetMechanic(
    title: 'Higiene',
    gameFunction: 'Registro de gastos',
    financialMeaning: 'Limpar gastos esquecidos e manter clareza.',
  ),
  PetMechanic(
    title: 'Energia',
    gameFunction: 'Taxa de poupança',
    financialMeaning: 'Quanto maior a taxa, mais rápido ele evolui.',
  ),
  PetMechanic(
    title: 'Saúde',
    gameFunction: 'Uso da reserva',
    financialMeaning: 'Saques de emergência reduzem acessórios futuros.',
  ),
];
