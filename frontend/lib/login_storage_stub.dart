final Map<String, String> _memoryStorage = {};

String? readString(String key) => _memoryStorage[key];

void writeString(String key, String value) {
  _memoryStorage[key] = value;
}

void removeString(String key) {
  _memoryStorage.remove(key);
}
