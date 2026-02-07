project('novabar', 'vala', 'c',
  version: '0.1.4',
  meson_version: '>= 0.50.0',
)

add_project_arguments(['-D', 'WNCK_I_KNOW_THIS_IS_UNSTABLE'], language: 'c')

dependencies = [
  dependency('gtk+-3.0'),
  dependency('glib-2.0'),
  dependency('gio-2.0'),
  dependency('gdk-x11-3.0'),
  dependency('libwnck-3.0'),
  dependency('x11'),
  dependency('libnm'),
  dependency('libsoup-3.0', required: false),
]

vala_args = []
c_sources = []

# Wayland support via gtk-layer-shell and wlr-foreign-toplevel
if get_option('wayland')
  gtk_layer_shell = dependency('gtk-layer-shell-0', required: false)
  wayland_client = dependency('wayland-client', required: false)
  
  if gtk_layer_shell.found() and wayland_client.found()
    dependencies += gtk_layer_shell
    dependencies += wayland_client
    vala_args += '--define=HAVE_WAYLAND'
    vala_args += '--vapidir=' + meson.current_source_dir() / 'src/wayland'
    vala_args += '--pkg=wlr-toplevel'
    
    # Generate protocol code
    wayland_scanner = find_program('wayland-scanner')
    wlr_toplevel_xml = files('protocols/wlr-foreign-toplevel-management-unstable-v1.xml')
    
    wlr_toplevel_header = custom_target('wlr-toplevel-header',
      input: wlr_toplevel_xml,
      output: 'wlr-foreign-toplevel-management-unstable-v1-client-protocol.h',
      command: [wayland_scanner, 'client-header', '@INPUT@', '@OUTPUT@'],
    )
    
    wlr_toplevel_code = custom_target('wlr-toplevel-code',
      input: wlr_toplevel_xml,
      output: 'wlr-foreign-toplevel-management-unstable-v1-client-protocol.c',
      command: [wayland_scanner, 'private-code', '@INPUT@', '@OUTPUT@'],
    )
    
    c_sources += ['src/wayland/wlr-toplevel.c', wlr_toplevel_code, wlr_toplevel_header]
  else
    warning('gtk-layer-shell or wayland-client not found, Wayland support disabled')
  endif
endif

sources = files(
  # Main
  'src/main.vala',
  'src/panel.vala',
  
  # Backend
  'src/backend/backend.vala',
  'src/backend/x11.vala',
  'src/backend/wayland.vala',
  'src/backend/popup.vala',
  
  # Toplevel Tracking
  'src/toplevel/tracker.vala',
  'src/toplevel/x11.vala',
  'src/toplevel/wayland.vala',
  
  # Global Menu
  'src/globalmenu/menubar.vala',
  'src/globalmenu/registrar.vala',
  'src/globalmenu/dbusmenu_client.vala',
  
  # Logo Menu
  'src/logomenu/logomenu.vala',
  
  # Indicators
  'src/indicators/datetime/datetime.vala',
  'src/indicators/sound/sound.vala',
  'src/indicators/network/network.vala',
  'src/indicators/network/enhanced_wrapper.vala',
  'src/indicators/bluetooth/bluetooth.vala',
  'src/indicators/bluetooth/enhanced_wrapper.vala',
  'src/indicators/battery/battery.vala',
  'src/indicators/notifications/notifications.vala',
  'src/indicators/controlcenter/controlcenter.vala',
  
  # Enhanced Network Indicator Models
  'src/indicators/network/enhanced/models/enums.vala',
  'src/indicators/network/enhanced/models/network_connection.vala',
  'src/indicators/network/enhanced/models/wifi_network.vala',
  'src/indicators/network/enhanced/models/vpn_profile.vala',
  'src/indicators/network/enhanced/models/hotspot_configuration.vala',
  'src/indicators/network/enhanced/models/mobile_connection.vala',
  'src/indicators/network/enhanced/models/network_profile.vala',
  
  # Enhanced Bluetooth Indicator Models
  'src/indicators/bluetooth/enhanced/models/enums.vala',
  'src/indicators/bluetooth/enhanced/models/bluetooth_adapter.vala',
  'src/indicators/bluetooth/enhanced/models/bluetooth_device.vala',
  'src/indicators/bluetooth/enhanced/models/audio_profile.vala',
  'src/indicators/bluetooth/enhanced/models/file_transfer.vala',
  'src/indicators/bluetooth/enhanced/models/pairing_request.vala',
  'src/indicators/bluetooth/enhanced/models/bluetooth_error.vala',
  
  # Enhanced Bluetooth Indicator Managers
  'src/indicators/bluetooth/enhanced/managers/bluez_client.vala',
  'src/indicators/bluetooth/enhanced/managers/adapter_manager.vala',
  'src/indicators/bluetooth/enhanced/managers/device_manager.vala',
  'src/indicators/bluetooth/enhanced/managers/agent_manager.vala',
  'src/indicators/bluetooth/enhanced/managers/audio_manager.vala',
  'src/indicators/bluetooth/enhanced/managers/transfer_manager.vala',
  
  # Enhanced Bluetooth Indicator Utils
  'src/indicators/bluetooth/enhanced/utils/error_handler.vala',
  'src/indicators/bluetooth/enhanced/utils/config_manager.vala',
  'src/indicators/bluetooth/enhanced/utils/polkit_client.vala',
  
  # Enhanced Bluetooth Indicator Controller
  'src/indicators/bluetooth/enhanced/bluetooth_controller.vala',
  
  # Enhanced Bluetooth Indicator Main Component
  'src/indicators/bluetooth/enhanced/bluetooth_indicator.vala',
  'src/indicators/bluetooth/enhanced/notification_manager.vala',
  
  # Enhanced Bluetooth Indicator UI Components
  'src/indicators/bluetooth/enhanced/ui/bluetooth_panel.vala',
  'src/indicators/bluetooth/enhanced/ui/bluetooth_popover.vala',
  'src/indicators/bluetooth/enhanced/ui/device_detail_view.vala',
  'src/indicators/bluetooth/enhanced/ui/pairing_dialog.vala',
  'src/indicators/bluetooth/enhanced/ui/settings_panel.vala',
  'src/indicators/bluetooth/enhanced/ui/keyboard_navigation.vala',
  'src/indicators/bluetooth/enhanced/ui/accessibility_helper.vala',
  
  # Enhanced Network Indicator Core Components
  'src/indicators/network/enhanced/nm_client.vala',
  'src/indicators/network/enhanced/network_monitor.vala',
  'src/indicators/network/enhanced/wifi_manager.vala',
  'src/indicators/network/enhanced/ethernet_manager.vala',
  'src/indicators/network/enhanced/vpn_manager.vala',
  'src/indicators/network/enhanced/mobile_manager.vala',
  'src/indicators/network/enhanced/hotspot_manager.vala',
  'src/indicators/network/enhanced/bandwidth_monitor.vala',
  'src/indicators/network/enhanced/security_analyzer.vala',
  'src/indicators/network/enhanced/network_profile_manager.vala',
  'src/indicators/network/enhanced/advanced_config_manager.vala',
  'src/indicators/network/enhanced/polkit_client.vala',
  'src/indicators/network/enhanced/error_handler.vala',
  
  # Enhanced Network Indicator UI Components
  'src/indicators/network/enhanced/network_indicator.vala',
  'src/indicators/network/enhanced/network_controller.vala',
  'src/indicators/network/enhanced/network_popover.vala',
  'src/indicators/network/enhanced/ui/network_panel.vala',
  'src/indicators/network/enhanced/ui/overview_panel.vala',
  'src/indicators/network/enhanced/ui/wifi_panel.vala',
  'src/indicators/network/enhanced/ui/ethernet_panel.vala',
  'src/indicators/network/enhanced/ui/vpn_panel.vala',
  'src/indicators/network/enhanced/ui/mobile_panel.vala',
  'src/indicators/network/enhanced/ui/hotspot_panel.vala',
  'src/indicators/network/enhanced/ui/monitor_panel.vala',
  'src/indicators/network/enhanced/ui/settings_panel.vala',
  'src/indicators/network/enhanced/ui/connection_dialog.vala',
  'src/indicators/network/enhanced/ui/keyboard_navigation.vala',
  'src/indicators/network/enhanced/ui/accessibility_helper.vala',
  'src/about/about.vala',
  'src/settings/settings.vala',
)

executable('novabar',
  sources, c_sources,
  dependencies: dependencies,
  vala_args: vala_args,
  include_directories: include_directories('src/wayland'),
  install: true,
)

install_data('data/novaos.css',
  install_dir: get_option('datadir') / 'novaos'
)

install_data('data/novaos-light.css',
  install_dir: get_option('datadir') / 'novaos'
)

# Application icon
install_data('data/icons/macos-style-icon-ofmenu-bar.png',
  rename: 'novabar.png',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / '256x256' / 'apps'
)
install_data('data/icons/macos-style-icon-ofmenu-bar.png',
  rename: 'novabar.png',
  install_dir: get_option('datadir') / 'pixmaps'
)

# Desktop files
install_data('novabar.desktop',
  install_dir: get_option('datadir') / 'applications'
)
install_data('novabar-autostart.desktop',
  install_dir: get_option('sysconfdir') / 'xdg' / 'autostart'
)

# Translations
subdir('po')

# Tests
if get_option('tests')
  subdir('tests')
endif
