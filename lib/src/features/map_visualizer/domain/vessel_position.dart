class VesselPosition {
  final int? id;
  final int buqueId;
  final DateTime fecha;
  final double latitud;
  final double longitud;
  final double? velocidad;
  final double? rumbo;

  VesselPosition({
    this.id,
    required this.buqueId,
    required this.fecha,
    required this.latitud,
    required this.longitud,
    this.velocidad,
    this.rumbo,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'buque_id': buqueId,
      'fecha': fecha.toIso8601String(),
      'latitud': latitud,
      'longitud': longitud,
      'velocidad': velocidad,
      'rumbo': rumbo,
    };
  }

  factory VesselPosition.fromMap(Map<String, dynamic> map) {
    return VesselPosition(
      id: map['id'] as int?,
      buqueId: map['buque_id'] as int,
      fecha: DateTime.parse(map['fecha'] as String).toUtc(),
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      velocidad: map['velocidad'] != null
          ? (map['velocidad'] as num).toDouble()
          : null,
      rumbo: map['rumbo'] != null ? (map['rumbo'] as num).toDouble() : null,
    );
  }
}
