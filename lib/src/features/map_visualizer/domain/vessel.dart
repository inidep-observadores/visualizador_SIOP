class Vessel {
  final int? id;
  final String nombre;
  final String matricula;

  Vessel({this.id, required this.nombre, required this.matricula});

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'nombre': nombre, 'matricula': matricula};
  }

  factory Vessel.fromMap(Map<String, dynamic> map) {
    return Vessel(
      id: map['id'] != null ? map['id'] as int : null,
      nombre: map['nombre']?.toString() ?? 'Sin nombre',
      matricula: map['matricula']?.toString() ?? 'S/M',
    );
  }

  Vessel copyWith({int? id, String? nombre, String? matricula}) {
    return Vessel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      matricula: matricula ?? this.matricula,
    );
  }
}
