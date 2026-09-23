/// Modelo para representar um técnico da equipe em campo
class Tecnico {
  final String id;
  final String nome;
  final String telefone;
  final String? email;
  final String? especialidade;
  final DateTime createdAt;

  Tecnico({
    required this.id,
    required this.nome,
    required this.telefone,
    this.email,
    this.especialidade,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'telefone': telefone,
      if (email != null) 'email': email,
      if (especialidade != null) 'especialidade': especialidade,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Tecnico.fromMap(Map<String, dynamic> map) {
    return Tecnico(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      telefone: map['telefone']?.toString() ?? '',
      email: map['email']?.toString(),
      especialidade: map['especialidade']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
