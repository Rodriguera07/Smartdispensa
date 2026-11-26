import 'package:material_ui/material_ui.dart';

/// Paleta "Fresh Tech & Glass" do Smart Dispensa.
///
/// Todas as cores do app saem daqui — nenhuma tela deve declarar cores
/// "soltas". Isso garante consistência visual e facilita ajustes de marca.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Fundos
  // ---------------------------------------------------------------------------

  /// Azul-Petróleo Profundo — base do gradiente escuro.
  static const Color petroleum = Color(0xFF0B192C);

  /// Verde-Esmeralda Escuro — final do gradiente escuro.
  static const Color deepEmerald = Color(0xFF0F292E);

  /// Fundo da variante clara.
  static const Color lightBackground = Color(0xFFF4F7F9);

  /// Final do gradiente claro (leve toque de menta).
  static const Color lightBackgroundEnd = Color(0xFFE6F4F1);

  // ---------------------------------------------------------------------------
  // Marca
  // ---------------------------------------------------------------------------

  /// Verde-Menta Tecnológico — cor primária de ação.
  static const Color mint = Color(0xFF00D09C);

  /// Variante mais escura do menta, usada no tema claro para manter contraste
  /// AA em textos e ícones sobre fundo claro.
  static const Color mintDark = Color(0xFF00876A);

  /// Ciano Elétrico — acentos e badges informativos.
  static const Color cyan = Color(0xFF00B4D8);

  /// Dourado Suave — exclusivo para selos Premium ✨.
  static const Color gold = Color(0xFFF5B700);

  // ---------------------------------------------------------------------------
  // Semânticas
  // ---------------------------------------------------------------------------

  static const Color danger = Color(0xFFFF5C6C);
  static const Color warning = Color(0xFFFFA940);
  static const Color success = mint;

  // ---------------------------------------------------------------------------
  // Texto
  // ---------------------------------------------------------------------------

  static const Color textOnDark = Color(0xFFF2F6FA);
  static const Color textOnDarkMuted = Color(0xFFA9B8C9);
  static const Color textOnLight = Color(0xFF0B192C);
  static const Color textOnLightMuted = Color(0xFF4D5E70);

  // ---------------------------------------------------------------------------
  // Glassmorphism
  // ---------------------------------------------------------------------------

  /// Borda fina 1px branca com 15% de opacidade (especificação do design).
  static const Color glassBorderDark = Color(0x26FFFFFF);
  static const Color glassBorderLight = Color(0x1A0B192C);

  /// Preenchimento translúcido dos cartões.
  static const Color glassFillDark = Color(0x14FFFFFF); // 8%
  static const Color glassFillLight = Color(0xB3FFFFFF); // 70%

  // ---------------------------------------------------------------------------
  // Gradientes
  // ---------------------------------------------------------------------------

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [petroleum, deepEmerald],
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightBackground, lightBackgroundEnd],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mint, cyan],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD54F), gold, Color(0xFFE09A00)],
  );
}
