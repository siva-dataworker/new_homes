/// Safe first-letter extraction for avatar initials.
///
/// `(name ?? 'S').substring(0, 1)` throws `RangeError` when the backend
/// returns an empty string rather than null — `??` only catches null.
/// This checks emptiness too.
String avatarInitial(String? name, [String fallback = '?']) {
  if (name == null || name.isEmpty) return fallback.toUpperCase();
  return name.substring(0, 1).toUpperCase();
}
