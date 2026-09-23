import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ats_documentacao.dart';
import 'offline_storage_service.dart';

/// Serviço responsável pelo gerenciamento, cache e sincronização das anotações e fotos de campo
class AtsDocumentacaoService {
  static final AtsDocumentacaoService instance = AtsDocumentacaoService._internal();
  AtsDocumentacaoService._internal();

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
        final remoteDoc = AtsDocumentacao.fromMap(res);
        // Combina as fotos locais existentes com as URLs remotas
        final combinedFotosUrls = {...localDoc.fotosUrls, ...remoteDoc.fotosUrls}.toList();
        final atualizado = remoteDoc.copyWith(
          fotosUrls: combinedFotosUrls,
          localFotosPaths: localDoc.localFotosPaths,
          pendingSync: false,
        );
        await OfflineStorageService.instance.salvarDocumentacaoLocal(atualizado);
        return atualizado;
      }
    } catch (e) {
      debugPrint('[AtsDocumentacaoService] Falha ao consultar Supabase (usando cache local): $e');
    }

    return localDoc;
  }

  /// Salva as anotações e fotos localmente no Hive e sincroniza com o Supabase quando disponível
  Future<AtsDocumentacao> salvarDocumentacao({
    required String chamadoId,
    required String anotacoes,
    required List<String> localFotosPaths,
    List<String>? fotosUrlsExistentes,
  }) async {
    final urlsFinais = List<String>.from(fotosUrlsExistentes ?? []);
    bool remotoSucesso = false;

    // 1. Salva estado inicial localmente como pendente
    var doc = AtsDocumentacao(
      chamadoId: chamadoId,
      anotacoesCampo: anotacoes,
      fotosUrls: urlsFinais,
      localFotosPaths: localFotosPaths,
      updatedAt: DateTime.now(),
      pendingSync: true,
    );
    await OfflineStorageService.instance.salvarDocumentacaoLocal(doc);

    // 2. Tenta fazer upload das fotos e sincronizar com o banco remoto
    try {
      final client = Supabase.instance.client;

      // Upload de fotos locais novas para o Storage (apenas em mobile/desktop com File existente)
      if (!kIsWeb) {
        for (final path in localFotosPaths) {
          final file = File(path);
          if (await file.exists()) {
            final fileName = path.split(Platform.pathSeparator).last;
            final remotePath = 'documentacoes/${chamadoId}_$fileName';

            try {
              final bytes = await file.readAsBytes();
              await client.storage.from('orcamentos').uploadBinary(
                remotePath,
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
              );
              final publicUrl = client.storage.from('orcamentos').getPublicUrl(remotePath);
              if (!urlsFinais.contains(publicUrl)) {
                urlsFinais.add(publicUrl);
              }
            } catch (upErr) {
              debugPrint('[AtsDocumentacaoService] Erro ao subir foto $fileName: $upErr');
            }
          }
        }
      }

      // Upsert na tabela ats_documentacoes
      doc = doc.copyWith(
        fotosUrls: urlsFinais,
        updatedAt: DateTime.now(),
      );

      await client.from('ats_documentacoes').upsert(
        doc.toDatabaseMap(),
        onConflict: 'chamado_id',
      );

      remotoSucesso = true;
    } catch (e) {
      debugPrint('[AtsDocumentacaoService] Erro ao sincronizar documentação com Supabase: $e');
    }

    // 3. Atualiza estado final com status de sincronização
    doc = doc.copyWith(pendingSync: !remotoSucesso);
    await OfflineStorageService.instance.salvarDocumentacaoLocal(doc);

    return doc;
  }
}
