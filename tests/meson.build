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

# Enhanced Bluetooth Indicator Tests

# Bluetooth Error Handler Test (standalone)
bluetooth_error_handler_test = executable('test_bluetooth_error_handler',
  files('enhanced-bluetooth-indicator/test_error_handler.vala'),
  dependencies: test_dependencies,
)

test('Bluetooth Error Handler Test', bluetooth_error_handler_test,
  timeout: 30,
  suite: 'enhanced-bluetooth-indicator'
)

# Bluetooth Adapter Manager Test
bluetooth_adapter_simple_test = executable('test_bluetooth_adapter_simple',
  files('enhanced-bluetooth-indicator/test_adapter_simple.vala'),
  dependencies: test_dependencies,
)

test('Bluetooth Adapter Simple Test', bluetooth_adapter_simple_test,
  timeout: 30,
  suite: 'enhanced-bluetooth-indicator'
)

# Bluetooth Device Manager Test
bluetooth_device_manager_test = executable('test_bluetooth_device_manager',
  files('enhanced-bluetooth-indicator/test_device_manager.vala'),
  dependencies: test_dependencies,
)

test('Bluetooth Device Manager Test', bluetooth_device_manager_test,
  timeout: 30,
  suite: 'enhanced-bluetooth-indicator'
)

# Bluetooth Agent Manager Test
bluetooth_agent_manager_test = executable('test_bluetooth_agent_manager',
  files('enhanced-bluetooth-indicator/test_agent_manager.vala'),
  dependencies: test_dependencies,
)

test('Bluetooth Agent Manager Test', bluetooth_agent_manager_test,
  timeout: 30,
  suite: 'enhanced-bluetooth-indicator'
)

# Bluetooth Audio Manager Test
bluetooth_audio_manager_test = executable('test_bluetooth_audio_manager',
  files('enhanced-bluetooth-indicator/test_audio_manager.vala'),
  dependencies: test_dependencies,
)

test('Bluetooth Audio Manager Test', bluetooth_audio_manager_test,
  timeout: 30,
  suite: 'enhanced-bluetooth-indicator'
)

# Bluetooth Transfer Manager Test
bluetooth_transfer_manager_test = executable('test_bluetooth_transfer_manager',
  files('enhanced-bluetooth-indicator/test_transfer_manager.vala'),
  dependencies: test_dependencies,
)

test('Bluetooth Transfer Manager Test', bluetooth_transfer_manager_test,
  timeout: 30,
  suite: 'enhanced-bluetooth-indicator'
)

# Bluetooth Config Manager Test
bluetooth_config_manager_test = executable('test_bluetooth_config_manager',
  files('enhanced-bluetooth-indicator/test_config_manager.vala'),
  dependencies: test_dependencies,
)

test('Bluetooth Config Manager Test', bluetooth_config_manager_test,
  timeout: 30,
  suite: 'enhanced-bluetooth-indicator'
)

# Bluetooth PolicyKit Client Test
bluetooth_polkit_client_test = executable('test_bluetooth_polkit_client',
  files('enhanced-bluetooth-indicator/test_polkit_client.vala'),
  dependencies: test_dependencies,
)

test('Bluetooth PolicyKit Client Test', bluetooth_polkit_client_test,
  timeout: 30,
  suite: 'enhanced-bluetooth-indicator'
)
