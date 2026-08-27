
int fastHash(String string) {
  // 1. Use the 32-bit FNV offset basis instead of the 64-bit one
  var hash = 0x811c9dc5; 

  for (var i = 0; i < string.length; i++) {
    final codeUnit = string.codeUnitAt(i);
    
    // Process the first 8 bits (Dart strings are 16-bit code units)
    hash ^= codeUnit >> 8;
    // Multiply by the 32-bit FNV prime. 
    // The bitwise AND (&) ensures the number never exceeds 32 bits in JS memory.
    hash = (hash * 0x01000193) & 0xFFFFFFFF; 

    // Process the second 8 bits
    hash ^= codeUnit & 0xFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  // 2. Ensure the final hash is strictly positive (Isar IDs must not be negative).
  // Applying 0x7FFFFFFF forces the sign bit to 0.
  return hash & 0x7FFFFFFF; 
}
