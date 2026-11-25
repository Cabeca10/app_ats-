import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/tecnico/tecnico_dashboard.dart';
import 'screens/gerente/gerente_dashboard.dart';
import 'screens/cliente/orcamento_client_screen.dart';
import 'services/offline_storage_service.dart';
import 'services/chamados_service.dart';
import 'services/tecnicos_service.dart';
export 'utils/url_helper.dart' show kAppBaseUrl;

// ============================================================================
// CONFIGURAÇÃO DO SUPABASE (REGRA DE APPSEC INEGOCIÁVEL)
// É terminantemente PROIBIDO incluir chaves administrativas privilegiadas no frontend.
// Inicializamos estritamente com a anonKey pública.
// ============================================================================
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://wdjoemplqzryixixosvh.supabase.co',
);
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_HRi1dpoQRwuIucisv8BhZg_aFAWm97b',
);

class AppAuthState {
  static String selectedRole = 'Técnico'; // 'Técnico' or 'Gerente'
  static String? currentUserRole; // 'gerente', 'tecnico', 'gerente_tecnico'
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Permite rotação livre em retrato (vertical) e paisagem (horizontal)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 1. Inicializa o Hive para persistência offline-first
  await OfflineStorageService.instance.init();

  // 1.1 Restaura o último perfil selecionado ('Gerente' ou 'Técnico') antes da renderização
  final savedRole = OfflineStorageService.instance.obterPerfilSelecionado();
  if (savedRole == 'Gerente' || savedRole == 'Técnico') {
    AppAuthState.selectedRole = savedRole!;
  }

  // 2. Inicializa o Supabase com estrita anon_key pública ANTES de qualquer serviço
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
    if (_session?.user != null) {
      _inicializarSessao(_session!.user);
    } else {
      _initialCheckDone = true;
    }
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (mounted) {
        setState(() {
          _session = data.session;
        });
      }
      if (data.session?.user != null) {
        _resolverPerfilAutomatico(data.session!.user);
        ChamadosService.instance.inicializarESincronizar();
      }
    });
  }

  Future<void> _inicializarSessao(User user) async {
    try {
      await _resolverPerfilAutomatico(user);
      ChamadosService.instance.inicializarESincronizar();
    } finally {
      if (mounted) {
        setState(() {
          _initialCheckDone = true;
        });
      }
    }
  }

  Future<void> _resolverPerfilAutomatico(User user) async {
    String? role;
    try {
      final row = await Supabase.instance.client
          .from('usuarios')
          .select('role, perfil')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        role = (row['role'] ?? row['perfil'])?.toString();
      }
    } catch (_) {}

    if (role == null || role.isEmpty) {
      role = user.appMetadata['role']?.toString() ??
          user.userMetadata?['role']?.toString();
    }

    TecnicosService.instance.inicializarESincronizar();

    if (role != null) {
      final normalizedRole = role.toLowerCase().trim();
      AppAuthState.currentUserRole = normalizedRole;

      final String novoRole;
      if (normalizedRole == 'gerente_tecnico') {
        // Perfil híbrido: mantém a aba selecionada pelo usuário (persistida no Hive)
        final rolePersistida =
            OfflineStorageService.instance.obterPerfilSelecionado();
        final efetiva = rolePersistida ?? AppAuthState.selectedRole;
        novoRole = (efetiva == 'Gerente') ? 'Gerente' : 'Técnico';
      } else if (normalizedRole == 'gerente') {
        novoRole = 'Gerente';
      } else {
        novoRole = 'Técnico';
      }

      await OfflineStorageService.instance.salvarPerfilSelecionado(novoRole);

      if (mounted && AppAuthState.selectedRole != novoRole) {
        setState(() {
          AppAuthState.selectedRole = novoRole;
        });
      } else {
        AppAuthState.selectedRole = novoRole;
      }
    }
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

    if (_session != null) {
      if (AppAuthState.selectedRole == 'Gerente') {
        return GerenteDashboard(
          onLogout: () {
            setState(() {});
          },
        );
      } else {
        return TecnicoDashboard(
          onLogout: () {
            setState(() {});
          },
        );
      }
    } else {
      return const LoginScreen();
    }
  }
}
