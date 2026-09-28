import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ma_boutique.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    // Table Produits
    await db.execute('''
    CREATE TABLE products (
      id $idType,
      shop_id $textType,
      name $textType,
      reference TEXT,
      barcode TEXT,
      category TEXT,
      purchase_price $realType,
      selling_price $realType,
      quantity $intType,
      alert_threshold INTEGER DEFAULT 5,
      unit TEXT,
      image_path TEXT,
      created_at $textType,
      updated_at $textType
    )
    ''');

    // Table Clients
    await db.execute('''
    CREATE TABLE customers (
      id $idType,
      shop_id $textType,
      name $textType,
      phone TEXT,
      address TEXT,
      created_at $textType
    )
    ''');

    // Table Ventes
    await db.execute('''
    CREATE TABLE sales (
      id $idType,
      shop_id $textType,
      customer_id TEXT,
      total_amount $realType,
      payment_method $textType,
      status TEXT DEFAULT 'COMPLETED',
      created_at $textType
    )
    ''');

    // Table File de Synchronisation
    await db.execute('''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      operation_type $textType,
      entity_type $textType,
      entity_id $textType,
      payload TEXT,
      created_at $textType,
      status TEXT DEFAULT 'PENDING',
      retry_count INTEGER DEFAULT 0,
      last_error TEXT
    )
    ''');

    // Table Articles de vente
    await db.execute('''
    CREATE TABLE sale_items (
      id $idType,
      sale_id $textType,
      product_id $textType,
      product_name $textType,
      unit_price $realType,
      purchase_price $realType,
      quantity $intType,
      subtotal $realType,
      FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
    )
    ''');

    // Table Crédits
    await db.execute('''
    CREATE TABLE credits (
      id $idType,
      shop_id $textType,
      customer_id $textType,
      total_amount $realType,
      paid_amount $realType DEFAULT 0,
      created_at $textType,
      due_date $textType,
      notes TEXT,
      status TEXT DEFAULT 'ACTIVE'
    )
    ''');

    // Table Remboursements de crédit
    await db.execute('''
    CREATE TABLE credit_payments (
      id $idType,
      credit_id $textType,
      amount $realType,
      payment_method $textType,
      payment_date $textType,
      comment TEXT,
      FOREIGN KEY (credit_id) REFERENCES credits(id) ON DELETE CASCADE
    )
    ''');

    // Table Sessions de caisse
    await db.execute('''
    CREATE TABLE cash_sessions (
      id $idType,
      shop_id $textType,
      opening_balance $realType,
      closing_balance REAL,
      theoretical_balance REAL,
      difference REAL,
      opened_at $textType,
      closed_at TEXT,
      status TEXT DEFAULT 'OPEN'
    )
    ''');

    // Table Mouvements de caisse
    await db.execute('''
    CREATE TABLE cash_movements (
      id $idType,
      session_id $textType,
      type $textType,
      amount $realType,
      category $textType,
      description TEXT,
      created_at $textType
    )
    ''');

    // Table Dépenses
    await db.execute('''
    CREATE TABLE expenses (
      id $idType,
      shop_id $textType,
      amount $realType,
      category $textType,
      description TEXT,
      expense_date $textType,
      created_at $textType
    )
    ''');

    // Table Fournisseurs
    await db.execute('''
    CREATE TABLE suppliers (
      id $idType,
      shop_id $textType,
      name $textType,
      phone TEXT,
      address TEXT,
      products_supplied TEXT,
      notes TEXT,
      created_at $textType
    )
    ''');

    // Table Transactions Fournisseurs
    await db.execute('''
    CREATE TABLE supplier_transactions (
      id $idType,
      supplier_id $textType,
      type $textType,
      amount $realType,
      description TEXT,
      transaction_date $textType,
      created_at $textType
    )
    ''');

    // Table Paramètres de la boutique
    await db.execute('''
    CREATE TABLE shop_settings (
      id TEXT PRIMARY KEY,
      shop_name TEXT NOT NULL,
      shop_logo_path TEXT,
      currency TEXT DEFAULT 'FCFA',
      address TEXT,
      phone TEXT,
      email TEXT,
      owner_name TEXT,
      updated_at TEXT NOT NULL
    )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        products_supplied TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
      ''');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_transactions (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_settings (
        id TEXT PRIMARY KEY,
        shop_name TEXT NOT NULL,
        shop_logo_path TEXT,
        currency TEXT DEFAULT 'FCFA',
        address TEXT,
        phone TEXT,
        email TEXT,
        owner_name TEXT,
        updated_at TEXT NOT NULL
      )
      ''');
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
