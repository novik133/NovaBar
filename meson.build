project('novabar', 'vala', 'c',
  version: '0.1.2',
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
  
  # Logo Menu
  'src/logomenu/logomenu.vala',
  
  # Indicators
  'src/indicators/datetime/datetime.vala',
  'src/indicators/sound/sound.vala',
  'src/indicators/network/network.vala',
  'src/indicators/bluetooth/bluetooth.vala',
  'src/indicators/battery/battery.vala',
  'src/indicators/notifications/notifications.vala',
  'src/indicators/controlcenter/controlcenter.vala',
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
