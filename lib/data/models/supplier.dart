class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? productsSupplied;
  final String? notes;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.productsSupplied,
    this.notes,
    required this.createdAt,
  });

  static String generateId() {
    return 'SUP-${DateTime.now().millisecondsSinceEpoch}';
  }

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? productsSupplied,
    String? notes,
    DateTime? createdAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      productsSupplied: productsSupplied ?? this.productsSupplied,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
