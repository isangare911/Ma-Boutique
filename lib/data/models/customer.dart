class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? address;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
  });

  static String generateId() {
    return 'CLI-${DateTime.now().millisecondsSinceEpoch}';
  }

  // Données mockées pour tester
  static List<Customer> mockCustomers = [
    Customer(
      id: '1',
      name: 'Adama Koné',
      phone: '+223 70 12 34 56',
    ),
    Customer(
      id: '2',
      name: 'Fatoumata Traoré',
      phone: '+223 76 54 32 10',
    ),
    Customer(
      id: '3',
      name: 'Moussa Diarra',
      phone: '+223 66 11 22 33',
    ),
    Customer(
      id: '4',
      name: 'Awa Diallo',
      phone: '+223 78 44 55 66',
    ),
    Customer(
      id: '5',
      name: 'Ibrahim Coulibaly',
      phone: '+223 65 77 88 99',
    ),
  ];
}
