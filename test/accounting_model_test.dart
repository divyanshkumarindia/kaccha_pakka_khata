import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaccha_pakka_khata/state/accounting_model.dart';
import 'package:kaccha_pakka_khata/models/accounting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Ensure SharedPreferences doesn't call into platform channels during tests
    SharedPreferences.setMockInitialValues({});
  });

  test('opening balances contribute to receiptsTotal', () async {
    final model = AccountingModel(userType: UserType.personal);
    // initial receipts should equal openings (which default to 0)
    model.setOpeningBalances(cash: 100.0, bank: 50.0, other: 10.0);
    expect(model.openingCash, 100.0);
    expect(model.openingBank, 50.0);
    expect(model.openingOther, 10.0);
    expect(model.receiptsTotal, 160.0);
  });

  test('adding entry and rows updates totals', () async {
    final model = AccountingModel(userType: UserType.personal);
    final key = model.receiptAccounts.keys.first;

    // Add an entry
    model.addEntryToAccount(key, receipt: true);
    final entry = model.receiptAccounts[key]!.last;
    expect(entry.rows.isNotEmpty, true);

    // Set a value on the first row
    final row = entry.rows.first;
    model.updateRowValue(key, entry.id, row.id, cash: 200.5, receipt: true);

    // receiptsTotal should include this 200.5
    expect(model.calculateAccountTotalByKey(key, receipt: true) >= 200.5, true);
    expect(model.receiptsTotal >= 200.5, true);

    // Remove the row and ensure totals drop
    model.removeRowFromEntry(key, entry.id, row.id, receipt: true);
    expect(model.calculateAccountTotalByKey(key, receipt: true) < 1.0, true);
  });
}
