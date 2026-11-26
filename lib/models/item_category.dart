import 'package:material_ui/material_ui.dart';

import '../core/utils/formatters.dart';

/// Setores do supermercado.
///
/// A ordem de declaração é a **ordem dos corredores** usada em
/// "Ordenar por Corredor" na lista de compras — imita o trajeto típico de um
/// supermercado brasileiro (entrada pelo hortifrúti, saída pela higiene).
///
/// Obs.: chamado `ItemCategory` (e não `ProductCategory`) para não colidir com
/// o tipo homônimo exportado pelo `purchases_flutter`.
enum ItemCategory {
  hortifruti('Hortifrúti', '🥬', Icons.eco_rounded, Color(0xFF4CD964)),
  padaria('Padaria', '🥖', Icons.bakery_dining_rounded, Color(0xFFE0A458)),
  carnes('Carnes e Frios', '🥩', Icons.set_meal_rounded, Color(0xFFFF6B6B)),
  laticinios('Laticínios', '🥛', Icons.icecream_rounded, Color(0xFF8EC5FF)),
  mercearia('Mercearia', '🥫', Icons.kitchen_rounded, Color(0xFFFFB84D)),
  bebidas('Bebidas', '🧃', Icons.local_drink_rounded, Color(0xFF00B4D8)),
  limpeza('Limpeza', '🧽', Icons.cleaning_services_rounded, Color(0xFF7FDBDA)),
  higiene('Higiene', '🧴', Icons.soap_rounded, Color(0xFFC49BFF)),
  outros('Outros', '🛍️', Icons.shopping_bag_rounded, Color(0xFFA9B8C9));

  const ItemCategory(this.label, this.emoji, this.icon, this.color);

  final String label;
  final String emoji;
  final IconData icon;
  final Color color;

  static ItemCategory fromName(String? name) => ItemCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => ItemCategory.outros,
      );

  // ---------------------------------------------------------------------------
  // Classificação automática por palavras-chave
  // ---------------------------------------------------------------------------

  /// Palavras-chave (já normalizadas, sem acento) por categoria. A primeira
  /// categoria que casar vence, então termos mais específicos vêm antes.
  static const Map<ItemCategory, List<String>> _keywords = {
    ItemCategory.limpeza: [
      'deterg', 'sabao po', 'sabao liq', 'lava roupa', 'amaciante',
      'desinf', 'agua sanit', 'cloro', 'alvejante', 'multiuso', 'esponja',
      'limpa', 'veja', 'pinho', 'lustra', 'saco lixo', 'saco p lixo',
      'inseticida', 'odorizador', 'bombril', 'la de aco', 'ype', 'omo',
      'flanela', 'vassoura', 'rodo',
    ],
    ItemCategory.higiene: [
      'shampoo', 'sh ', 'condicionador', 'cond ', 'sabonete', 'sab ',
      'creme dent', 'cr dent', 'pasta dent', 'escova dent', 'fio dental',
      'desodorante', 'desod', 'papel hig', 'pap hig', 'absorvente',
      'fralda', 'barbear', 'aparelho', 'algodao', 'cotonete', 'hastes',
      'protetor', 'hidratante', 'lenco umed', 'enxaguante', 'colgate',
    ],
    ItemCategory.bebidas: [
      'refrig', 'refri', 'coca', 'guarana', 'suco', 'nectar', 'cerveja',
      'cerv ', 'vinho', 'agua min', 'agua c gas', 'agua s gas', 'energetico',
      'cha ', 'isotonico', 'vodka', 'whisky', 'cachaca', 'pepsi', 'fanta',
      'sprite', 'del valle', 'skol', 'brahma', 'heineken', 'itubaina',
    ],
    ItemCategory.laticinios: [
      'leite', 'iogurte', 'iog ', 'queijo', 'qjo', 'mussarela', 'muss ',
      'requeijao', 'req ', 'manteiga', 'margarina', 'creme de leite',
      'cr leite', 'nata', 'coalhada', 'danone', 'petit suisse', 'ricota',
      'cream cheese', 'leite cond', 'bebida lactea',
    ],
    ItemCategory.carnes: [
      'carne', 'frango', 'file', 'fil ', 'peito', 'coxa', 'sobrecoxa',
      'asa ', 'bovin', 'suin', 'picanha', 'alcatra', 'patinho', 'acem',
      'costela', 'linguica', 'ling ', 'salsicha', 'presunto', 'apresuntado',
      'mortadela', 'salame', 'bacon', 'peixe', 'tilapia', 'salmao',
      'sardinha fresca', 'hamburguer', 'carne moida', 'peru', 'calabresa',
      'ovos', 'ovo ',
    ],
    ItemCategory.padaria: [
      'pao', 'bisnaguinha', 'torrada', 'bolo', 'rosca', 'croissant',
      'baguete', 'sonho', 'broa', 'pao de queijo',
    ],
    ItemCategory.hortifruti: [
      'banana', 'maca', 'laranja', 'limao', 'mamao', 'melancia', 'melao',
      'abacaxi', 'uva', 'morango', 'manga', 'pera', 'tomate', 'batata',
      'cebola', 'alho', 'cenoura', 'alface', 'couve', 'repolho', 'brocolis',
      'abobrinha', 'abobora', 'pepino', 'pimentao', 'chuchu', 'beterraba',
      'mandioca', 'aipim', 'inhame', 'cheiro verde', 'salsa', 'coentro',
      'hortifruti', 'hort ', 'fruta', 'verdura', 'legume', 'kiwi', 'goiaba',
      'maracuja', 'abacate',
    ],
    ItemCategory.mercearia: [
      'arroz', 'feijao', 'acucar', 'acuc ', 'cafe', 'macarrao', 'mac ',
      'espaguete', 'farinha', 'far ', 'oleo', 'azeite', 'sal ', 'sal refin',
      'molho', 'extrato', 'atomatado', 'milho', 'ervilha', 'sardinha',
      'atum', 'biscoito', 'bisc ', 'bolacha', 'cereal', 'aveia', 'granola',
      'achocolatado', 'nescau', 'toddy', 'chocolate', 'choc ', 'fuba',
      'tempero', 'maionese', 'ketchup', 'mostarda', 'vinagre', 'gelatina',
      'leite em po', 'miojo', 'lamen', 'pipoca', 'amendoim', 'goiabada',
      'doce', 'mel ', 'geleia', 'polvilho', 'tapioca', 'fermento',
      'creme de arroz', 'massa', 'pure',
    ],
  };

  /// Sugere a categoria de um produto pelo nome (ex.: vindo do OCR).
  static ItemCategory guess(String productName) {
    // Espaço extra no fim permite casar termos abreviados como "sab ".
    final n = '${TextUtils.normalize(productName)} ';
    for (final entry in _keywords.entries) {
      for (final keyword in entry.value) {
        if (n.startsWith(keyword) || n.contains(' $keyword')) {
          return entry.key;
        }
      }
    }
    return ItemCategory.outros;
  }
}
