# Enhanced Network Indicator Tests

test_dependencies = [
  dependency('gtk+-3.0'),
  dependency('glib-2.0'),
  dependency('gio-2.0'),
  dependency('libnm'),
]

# Error Handler Test (standalone)
error_handler_test = executable('test_error_handler',
  files('enhanced-network-indicator/test_error_handler.vala'),
  dependencies: test_dependencies,
)

test('Error Handler Test', error_handler_test,
  timeout: 30,
  suite: 'enhanced-network-indicator'
)

# Simple Backend Integration Test (without full source dependencies)
simple_backend_test = executable('test_simple_backend',
  files('enhanced-network-indicator/test_simple_backend.vala'),
  dependencies: test_dependencies,
)

test('Simple Backend Test', simple_backend_test,
  timeout: 60,
  suite: 'enhanced-network-indicator'
)