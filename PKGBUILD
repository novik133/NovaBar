# Maintainer: novik133 <your-email@example.com>
pkgname=novabar
pkgver=0.1.0
pkgrel=1
pkgdesc="A modern, modular macOS-style panel for Linux (X11/XFCE) built with Vala and GTK3"
arch=('x86_64')
url="https://github.com/novik133/NovikBar"
license=('GPL3')
depends=('gtk3' 'glib2' 'libwnck3' 'networkmanager' 'libx11' 'appmenu-gtk-module')
makedepends=('vala' 'meson' 'ninja' 'pkgconf')
source=("$pkgname-$pkgver.tar.gz::https://github.com/novik133/NovikBar/archive/v$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
    cd "$srcdir/NovikBar-$pkgver"
    arch-meson . build
    meson compile -C build
}

package() {
    cd "$srcdir/NovikBar-$pkgver"
    meson install -C build --destdir "$pkgdir"
    
    # Install desktop file
    install -Dm644 "$srcdir/$pkgname.desktop" "$pkgdir/usr/share/applications/$pkgname.desktop"
    
    # Install autostart file
    install -Dm644 "$srcdir/$pkgname-autostart.desktop" "$pkgdir/etc/xdg/autostart/$pkgname.desktop"
}
