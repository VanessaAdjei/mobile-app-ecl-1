/// Redacts common PII/secrets before writing API payloads to debug logs.
dynamic redactSensitiveLogFields(dynamic value) {
  const sensitive = {
    'email',
    'phone',
    'number',
    'addr_1',
    'address',
    'fname',
    'name',
    'current_password',
    'new_password',
    'confirm_password',
    'password',
    'token',
  };

  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key: sensitive.contains(entry.key.toString())
            ? '***'
            : redactSensitiveLogFields(entry.value),
    };
  }
  if (value is List) {
    return value.map(redactSensitiveLogFields).toList();
  }
  return value;
}
