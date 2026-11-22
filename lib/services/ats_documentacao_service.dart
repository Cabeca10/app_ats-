import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/ats_documentacao.dart';
import 'offline_storage_service.dart';

/// Serviço responsável pelo gerenciamento, cache e sincronização das anotações e fotos de campo
class AtsDocumentacaoService {
  static final AtsDocumentacaoService instance = AtsDocumentacaoService._internal();
  AtsDocumentacaoService._internal();

  /// Faz upload direto dos bytes da foto para o Supabase Storage (compatível com Web e Mobile)
  Future<String?> uploadFotoBytes({
    required String chamadoId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final trimmedName = fileName.trim();
    if (trimmedName.toLowerCase().endsWith('.svg')) {
      throw Exception('Upload de arquivos SVG é bloqueado por diretrizes de segurança.');
    }

    final bool isPng = (bytes.length >= 4 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47) ||
        trimmedName.toLowerCase().endsWith('.png');
    final contentType = isPng ? 'image/png' : 'image/jpeg';

    var safeName = trimmedName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (safeName.isEmpty) {
      safeName = isPng ? 'foto.png' : 'foto.jpg';
    }
    final uniqueSuffix = const Uuid().v4().substring(0, 8);
    final remotePath =
        'documentacoes/${chamadoId}_${DateTime.now().millisecondsSinceEpoch}_${uniqueSuffix}_$safeName';

    final client = Supabase.instance.client;
    await client.storage.from('orcamentos').uploadBinary(
          remotePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from('orcamentos').getPublicUrl(remotePath);
  }

  /// Remove uma foto da documentação do Storage (best-effort)
  Future<void> removerFotoStorage(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed.contains('storage.local') || !trimmed.contains('/orcamentos/')) {
      return;
    }
    try {
      var path = trimmed.split('/orcamentos/').last.split('?').first;
      try {
        path = Uri.decodeFull(path);
      } catch (_) {}
      path = path.replaceFirst(RegExp(r'^/+'), '').trim();
      if (path.isNotEmpty) {
        await Supabase.instance.client.storage.from('orcamentos').remove([path]);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AtsDocumentacaoService] Aviso ao remover foto do Storage: $e');
      }
    }
  }

  /// Carrega a documentação do chamado (traz do Hive local imediatamente e atualiza via Supabase caso online)
  Future<AtsDocumentacao> obterDocumentacao(String chamadoId) async {
    // 1. Tenta recuperar do cache local offline
    AtsDocumentacao? localDoc = OfflineStorageService.instance.obterDocumentacaoLocal(chamadoId);
    localDoc ??= AtsDocumentacao(chamadoId: chamadoId);

    // 2. Se online, busca dados atualizados no Supabase
    try {
      final res = await Supabase.instance.client
          .from('ats_documentacoes')
          .select()
          .eq('chamado_id', chamadoId)
          .maybeSingle();

      if (res != null) {
        final remoteDoc = AtsDocumentacao.fromMap(Map<String, dynamic>.from(res));
        final mergedItens = List<FotoDocumentacaoItem>.from(remoteDoc.itensFotos);

        if (localDoc.pendingSync) {
          for (final localItem in localDoc.itensFotos) {
            final temPendenciaLocal = localItem.fotos.any(
              (f) => f.url.trim().isEmpty && f.localPath.trim().isNotEmpty,
            );
            if (temPendenciaLocal && !mergedItens.any((r) => r.id == localItem.id)) {
              mergedItens.add(localItem);
            }
          }
        }

        final combinedUrls = mergedItens
            .expand((e) => e.urlsValidas)
            .toList();

        final atualizado = remoteDoc.copyWith(
          itensFotos: mergedItens,
          fotosUrls: combinedUrls.isNotEmpty ? combinedUrls : remoteDoc.fotosUrls,
          localFotosPaths: mergedItens
              .expand((e) => e.fotos.map((f) => f.localPath))
              .where((p) => p.trim().isNotEmpty)
              .toList(),
          pendingSync: false,
        );
        await OfflineStorageService.instance.salvarDocumentacaoLocal(atualizado);
        return atualizado;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AtsDocumentacaoService] Falha ao consultar Supabase (usando cache local): $e');
      }
    }

    return localDoc;
  }

  /// Lista todas as documentações registradas (para visão de Registro de Chamados do Gerente)
  Future<Map<String, AtsDocumentacao>> listarTodasDocumentacoes() async {
    try {
      final res = await Supabase.instance.client
          .from('ats_documentacoes')
          .select('id, chamado_id, anotacoes_campo, fotos_urls, itens_fotos, created_at, updated_at');

      final mapa = <String, AtsDocumentacao>{};
      for (final row in (res as List)) {
        final doc = AtsDocumentacao.fromMap(Map<String, dynamic>.from(row as Map));
        if (doc.chamadoId.isNotEmpty) {
          mapa[doc.chamadoId] = doc;
        }
      }
      return mapa;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AtsDocumentacaoService] Erro ao listar todas as documentações: $e');
      }
      return {};
    }
  }

  /// Salva as anotações e itens fotográficos localmente no Hive e sincroniza com o Supabase quando disponível
  Future<AtsDocumentacao> salvarDocumentacao({
    required String chamadoId,
    required String anotacoes,
    required List<FotoDocumentacaoItem> itensFotos,
  }) async {
    final existenteLocal = OfflineStorageService.instance.obterDocumentacaoLocal(chamadoId);
    final itensAtualizados = List<FotoDocumentacaoItem>.from(itensFotos);
    bool remotoSucesso = false;

    List<String> extrairUrls() => itensAtualizados
        .expand((e) => e.urlsValidas)
        .toList();

    List<String> extrairLocalPaths() => itensAtualizados
        .expand((e) => e.fotos.map((f) => f.localPath.trim()))
        .where((p) => p.isNotEmpty)
        .toList();

    // 1. Salva estado inicial localmente como pendente
    var doc = AtsDocumentacao(
      id: existenteLocal?.id,
      chamadoId: chamadoId,
      anotacoesCampo: anotacoes,
      fotosUrls: extrairUrls(),
      localFotosPaths: extrairLocalPaths(),
      itensFotos: itensAtualizados,
      createdAt: existenteLocal?.createdAt,
      updatedAt: DateTime.now(),
      pendingSync: true,
    );
    await OfflineStorageService.instance.salvarDocumentacaoLocal(doc);

    // 2. Tenta enviar fotos pendentes (Mobile/Desktop) e sincronizar com o banco remoto
    try {
      final client = Supabase.instance.client;

      if (!kIsWeb) {
        for (int i = 0; i < itensAtualizados.length; i++) {
          final item = itensAtualizados[i];
          final fotosAtualizadas = List<FotoMidiaItem>.from(item.fotos);
          bool alterouFoto = false;

          for (int j = 0; j < fotosAtualizadas.length; j++) {
            final foto = fotosAtualizadas[j];
            if (foto.url.trim().isEmpty && foto.localPath.trim().isNotEmpty) {
              final file = File(foto.localPath);
              if (await file.exists()) {
                final fileName = foto.localPath.split(Platform.pathSeparator).last;
                if (fileName.toLowerCase().endsWith('.svg')) {
                  continue;
                }
                try {
                  final bytes = await file.readAsBytes();
                  final publicUrl = await uploadFotoBytes(
                    chamadoId: chamadoId,
                    bytes: bytes,
                    fileName: fileName,
                  );
                  if (publicUrl != null && publicUrl.isNotEmpty) {
                    fotosAtualizadas[j] = foto.copyWith(url: publicUrl);
                    alterouFoto = true;
                  }
                } catch (upErr) {
                  if (kDebugMode) {
                    debugPrint('[AtsDocumentacaoService] Erro ao subir foto $fileName: $upErr');
                  }
                }
              }
            }
          }

          if (alterouFoto) {
            itensAtualizados[i] = item.copyWith(fotos: fotosAtualizadas);
          }
        }
      }

      doc = doc.copyWith(
        fotosUrls: extrairUrls(),
        localFotosPaths: extrairLocalPaths(),
        itensFotos: itensAtualizados,
        updatedAt: DateTime.now(),
      );

      await client.from('ats_documentacoes').upsert(
            doc.toDatabaseMap(),
            onConflict: 'chamado_id',
          );

      remotoSucesso = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AtsDocumentacaoService] Erro ao sincronizar documentação com Supabase: $e');
      }
    }

    // 3. Atualiza estado final com status de sincronização
    doc = doc.copyWith(pendingSync: !remotoSucesso);
    await OfflineStorageService.instance.salvarDocumentacaoLocal(doc);

    return doc;
  }
}
