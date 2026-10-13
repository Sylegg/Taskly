import 'models.dart';

/// A backend implementation can emit the same invalidations from realtime events.
abstract interface class RepositoryUpdates {
  Stream<void> get changes;
}

abstract interface class CatalogueRefresh {
  Future<CustomerSnapshot> refreshCatalogue();
}
