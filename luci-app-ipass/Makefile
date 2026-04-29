include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ipass
PKG_VERSION:=0.3.7
PKG_RELEASE:=1

LUCI_TITLE:=LuCI support for iPass Connectivity Check
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+curl +luci-compat +libuci-lua +luci-lib-jsonc

define Package/$(PKG_NAME)/conffiles
/etc/config/ipass
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
