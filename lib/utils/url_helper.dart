import 'package:flutter/foundation.dart';

/// Constante configurável em tempo de compilação ou execução via:
/// `--dart-define=APP_BASE_URL=https://ats.pmach.com.br` ou túnel `https://meu-tunel.loca.lt`
const String kAppBaseUrl = String.fromEnvironment(
  'APP_BASE_URL',
  defaultValue: 'https://pmach-ats.web.app', // Domínio web oficial definitivo
);

/// Utilitário centralizado para geração de URLs públicas e tratamento de rotas no Flutter Web
class UrlHelper {
  /// Retorna a URL base limpa da aplicação web
  static String get baseUrl {
    if (kAppBaseUrl.trim().isNotEmpty) {
      return kAppBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && origin != 'null' && !origin.contains('localhost') && !origin.contains('127.0.0.1')) {
          return origin.replaceAll(RegExp(r'/+$'), '');
        }
      } catch (_) {}
    }

    if (Uri.base.hasAuthority && Uri.base.authority.isNotEmpty && !Uri.base.authority.contains('localhost') && !Uri.base.authority.contains('127.0.0.1')) {
      return '${Uri.base.scheme}://${Uri.base.authority}'.replaceAll(RegExp(r'/+$'), '');
    }

    return 'https://pmach-ats.web.app';
  }

  /// Constrói a URL pública do orçamento / proposta comercial com o token fornecido
  static String buildOrcamentoUrl(String token) {
    final base = baseUrl;
    return '$base/#/orcamento?token=$token';
  }
}
