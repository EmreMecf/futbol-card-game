import 'store_client.dart';

/// Web: uygulama içi satın alma yok (mobilde alınan içerik kullanılır)
StoreClient createStoreClient() => const NoStoreClient();
