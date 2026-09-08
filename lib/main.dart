import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/tecnico/tecnico_dashboard.dart';
import 'screens/gerente/gerente_dashboard.dart';
import 'screens/cliente/orcamento_client_screen.dart';

// ============================================================================
// CONFIGURAÇÃO DO SUPABASE
// Por segurança, as credenciais são lidas via variáveis de ambiente (--dart-define)
// ou configuradas localmente no seu ambiente de desenvolvimento.
// ============================================================================
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://your-supabase-url.supabase.co',
);
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'your-supabase-anon-key',
);

class AppAuthState {
  static String selectedRole = 'Técnico'; // 'Técnico' or 'Gerente'
  static bool bypassAuth = false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: kSupabaseUrl,
      // ignore: deprecated_member_use
      anonKey: kSupabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Aviso na inicialização do Supabase: $e');
  }

  runApp(const MyApp());
}

/// Extrai o token público de orçamento a partir da rota ou da URL do navegador (Web)
String? _extrairTokenPublico(Uri uri) {
  // 1. Verifica parâmetro de query ?token=...
  if (uri.queryParameters.containsKey('token') &&
      uri.queryParameters['token']!.isNotEmpty) {
    return uri.queryParameters['token'];
  }

  // 2. Verifica segmentos de caminho: /orcamento/:token ou /aprovar/:token
  if (uri.pathSegments.isNotEmpty) {
    final first = uri.pathSegments.first.toLowerCase();
    if ((first == 'orcamento' || first == 'aprovar') &&
        uri.pathSegments.length > 1) {
      final possibleToken = uri.pathSegments[1].trim();
      if (possibleToken.isNotEmpty) return possibleToken;
    }
  }

  // 3. Suporte ao padrão de hash routing do Flutter Web: /#/orcamento?token=... ou /#/aprovar/...
  if (uri.hasFragment && uri.fragment.isNotEmpty) {
    try {
      final fragmentPath =
          uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
      final fragmentUri = Uri.parse(fragmentPath);
      return _extrairTokenPublico(fragmentUri);
    } catch (_) {}
  }

  return null;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Detecta se a URL inicial do navegador na Web já possui o token público
    final webInitialToken = _extrairTokenPublico(Uri.base);

    return MaterialApp(
      title: 'ATS Serviços - Equipamentos e Peças Ltda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A369D),
          primary: const Color(0xFF0A369D),
          secondary: const Color(0xFF4A90E2),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // Se na inicialização web houver token, abre DIRETO o orçamento sem passar pelo AuthWrapper
      home:
          webInitialToken != null
              ? OrcamentoClientScreen(token: webInitialToken)
              : null,
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        final publicToken =
            _extrairTokenPublico(uri) ?? _extrairTokenPublico(Uri.base);

        if (publicToken != null) {
          return MaterialPageRoute(
            builder: (_) => OrcamentoClientScreen(token: publicToken),
            settings: settings,
          );
        }

        return MaterialPageRoute(
          builder: (_) => const AuthWrapper(),
          settings: settings,
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _initialCheckDone = false;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _initialCheckDone = true;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      setState(() {
        _session = data.session;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialCheckDone) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0A369D)),
        ),
      );
    }

    if (_session != null || AppAuthState.bypassAuth) {
      if (AppAuthState.selectedRole == 'Gerente') {
        return GerenteDashboard(
          onLogout: () {
            setState(() {
              AppAuthState.bypassAuth = false;
            });
          },
        );
      } else {
        return TecnicoDashboard(
          onLogout: () {
            setState(() {
              AppAuthState.bypassAuth = false;
            });
          },
        );
      }
    } else {
      return LoginScreen(onBypass: () => setState(() {}));
    }
  }
}
