class SyncPair {
  const SyncPair({
    required this.id,
    required this.localPath,
    required this.devicePath,
    required this.mode,
    required this.enabled,
  });

  final String id;
  final String localPath;
  final String devicePath;
  final String mode;
  final bool enabled;
}
