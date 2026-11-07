# SmartRide patch

Vendored copy of vector_map_tiles 8.0.0 (BSD licence, see LICENSE). Upstream does
not run in a browser; two small changes make it work there. Mobile and desktop
behave as upstream.

1. `lib/src/cache/storage_cache.dart`: on web the tile cache lives in memory
   (oldest entries dropped first). The disk cache uses `dart:io`, which a browser
   does not have, and threw on the first tile.
2. `lib/src/grid/grid_layer.dart`: on web jobs run on the UI thread
   (`QueueExecutor`). Outside debug mode the package builds an isolate pool, which
   a browser cannot create, and tiles silently never loaded.
