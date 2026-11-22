/// Modelo para representar um técnico da equipe em campo
class Tecnico {
  final String id;
  final String nome;
  final String telefone;
  String get fone => telefone;
  final String? email;
  final String? especialidade;
  final String role;
  final bool ativo;
  final DateTime createdAt;

  Tecnico({
    required this.id,
    required this.nome,
    required this.telefone,
    this.email,
    this.especialidade,
    this.role = 'tecnico',
    this.ativo = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Tecnico copyWith({
    String? id,
    String? nome,
    String? telefone,
    String? email,
    String? especialidade,
    String? role,
    bool? ativo,
    DateTime? createdAt,
  }) {
    return Tecnico(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      especialidade: especialidade ?? this.especialidade,
      role: role ?? this.role,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'telefone': telefone,
      'fone': telefone,
      if (email != null) 'email': email,
      if (especialidade != null) 'especialidade': especialidade,
      'role': role,
      'perfil': role,
      'ativo': ativo,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Tecnico.fromMap(Map<String, dynamic> map) {
    final rawRole = (map['role'] ?? map['perfil'])?.toString().trim().toLowerCase();
    return Tecnico(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      telefone: (map['telefone'] ?? map['fone'])?.toString() ?? '',
      email: map['email']?.toString(),
      especialidade: map['especialidade']?.toString(),
      role: (rawRole != null && rawRole.isNotEmpty) ? rawRole : 'tecnico',
      ativo: map['ativo'] is bool ? (map['ativo'] as bool) : true,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : (map['criado_em'] != null
              ? (DateTime.tryParse(map['criado_em'].toString()) ?? DateTime.now())
              : DateTime.now()),
    );
  }
}
