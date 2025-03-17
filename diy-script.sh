#!/bin/bash

# 修改默认IP为192.168.88.1
sed -i 's/192.168.1.1/192.168.88.1/g' package/base-files/files/bin/config_generate
sed -i 's/option ipaddr '192.168.1.1'/option ipaddr '192.168.88.1'/g' package/base-files/files/etc/config/network
sed -i 's/192.168.1.1/192.168.88.1/g' package/base-files/files/etc/config/firewall

# 配置 LAN 口 (br-lan) 绑定 eth0 和 eth3
sed -i 's/option ifname.*/option ifname "eth0 eth3"/g' package/base-files/files/bin/config_generate
sed -i 's/option type.*/option type "bridge"/g' package/base-files/files/bin/config_generate

# 配置 WAN 口 (eth1) 为 PPPoE 拨号
sed -i 's/option ifname.*/option ifname "eth1"/g' package/base-files/files/bin/config_generate
sed -i 's/option proto.*/option proto "pppoe"/g' package/base-files/files/bin/config_generate

# 配置 WAN1 口 (eth2) 为 PPPoE 拨号
sed -i 's/option ifname.*/option ifname "eth2"/g' package/base-files/files/bin/config_generate
sed -i 's/option proto.*/option proto "pppoe"/g' package/base-files/files/bin/config_generate

# 设置 WAN 拨号账户
sed -i 's/option username.*/option username "$WRT_WAN_USER"/g' package/base-files/files/bin/config_generate
sed -i 's/option password.*/option password "$WRT_WAN_PASSWORD"/g' package/base-files/files/bin/config_generate

# 设置 WAN1 拨号账户
sed -i 's/option username.*/option username "$WRT_WAN1_USER"/g' package/base-files/files/bin/config_generate
sed -i 's/option password.*/option password "$WRT_WAN1_PASSWORD"/g' package/base-files/files/bin/config_generate

# 配置 LAN DHCP 设置
sed -i 's/option start.*/option start "10"/g' package/base-files/files/bin/config_generate
sed -i 's/option limit.*/option limit "100"/g' package/base-files/files/bin/config_generate
sed -i 's/option leasetime.*/option leasetime "12h"/g' package/base-files/files/bin/config_generate


echo "🚀 正在优化 OpenWrt 运行流畅度..."

# ✅ 1. 启用 irqbalance（多核 CPU 负载均衡）
if [ $(nproc) -gt 1 ]; then
    echo "CONFIG_PACKAGE_irqbalance=y" >> .config
    mkdir -p package/base-files/files/etc/init.d
    echo '#!/bin/sh' > package/base-files/files/etc/init.d/irqbalance
    echo '/etc/init.d/irqbalance start' >> package/base-files/files/etc/init.d/irqbalance
    chmod +x package/base-files/files/etc/init.d/irqbalance
fi

# ✅ 2. 启用 BBR 拥塞控制（提高网络吞吐量）
if uname -r | grep -qE "5\\."; then
    echo "net.core.default_qdisc=fq" >> package/base-files/files/etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> package/base-files/files/etc/sysctl.conf
fi

# ✅ 3. 启用 Flow Offloading（NAT 硬件加速）
mkdir -p package/base-files/files/etc/config
cat <<EOF > package/base-files/files/etc/config/firewall
config defaults
    option flow_offloading '1'
    option flow_offloading_hw '1'
EOF

# ✅ 4. 内存优化：启用 ZRAM（减少 RAM 占用，提高流畅度）
if [ $(free -m | awk '/Mem:/ {print $2}') -gt 128 ]; then
    echo "CONFIG_PACKAGE_zram-swap=y" >> .config
    mkdir -p package/base-files/files/etc/init.d
    echo '#!/bin/sh' > package/base-files/files/etc/init.d/zram
    echo '/etc/init.d/zram start' >> package/base-files/files/etc/init.d/zram
    chmod +x package/base-files/files/etc/init.d/zram
fi

# ✅ 5. 存储优化：减少 Flash 读写，将日志存到内存（tmpfs）
mkdir -p package/base-files/files/etc
cat <<EOF > package/base-files/files/etc/fstab
tmpfs /var/log tmpfs defaults,size=16m 0 0
EOF

# ✅ 6. 网络优化：优化 TCP 连接管理，减少不必要的连接占用
mkdir -p package/base-files/files/etc
cat <<EOF > package/base-files/files/etc/sysctl.conf
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_max_syn_backlog=4096
EOF

echo "✅ OpenWrt 流畅度优化完成!"


# 更改默认 Shell 为 zsh
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# TTYD 免登录
# sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 移除要替换的包
rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/net/msd_lite
rm -rf feeds/packages/net/smartdns
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-netgear
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-netdata
rm -rf feeds/luci/applications/luci-app-serverchan

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# 添加额外插件
# git clone --depth=1 https://github.com/kongfl888/luci-app-adguardhome package/luci-app-adguardhome
# git clone --depth=1 -b openwrt-18.06 https://github.com/tty228/luci-app-wechatpush package/luci-app-serverchan
# git clone --depth=1 https://github.com/ilxp/luci-app-ikoolproxy package/luci-app-ikoolproxy
git clone --depth=1 https://github.com/esirplayground/luci-app-poweroff package/luci-app-poweroff
# git clone --depth=1 https://github.com/destan19/OpenAppFilter package/OpenAppFilter
#git clone --depth=1 https://github.com/Jason6111/luci-app-netdata package/luci-app-netdata
# git_sparse_clone main https://github.com/Lienol/openwrt-package luci-app-filebrowser luci-app-ssr-mudb-server
# git_sparse_clone openwrt-18.06 https://github.com/immortalwrt/luci applications/luci-app-eqos
# git_sparse_clone master https://github.com/syb999/openwrt-19.07.1 package/network/services/msd_lite

# 科学上网插件
# git clone --depth=1 -b main https://github.com/fw876/helloworld package/luci-app-ssr-plus
# git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall-packages package/openwrt-passwall
# git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall package/luci-app-passwall
# git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall2 package/luci-app-passwall2
git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash

# Themes
git clone --depth=1 -b 18.06 https://github.com/kiddin9/luci-theme-edge package/luci-theme-edge
git clone --depth=1 -b 18.06 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth=1 https://github.com/xiaoqingfengATGH/luci-theme-infinityfreedom package/luci-theme-infinityfreedom
git_sparse_clone main https://github.com/haiibo/packages luci-theme-atmaterial luci-theme-opentomcat luci-theme-netgear

# 更改 Argon 主题背景
# cp -f $GITHUB_WORKSPACE/images/bg1.jpg package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# 修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")


#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	cd ./luci-theme-argon/

	sed -i '/font-weight:/ {/!important/! s/\(font-weight:\s*\)[^;]*;/\1normal;/}' $(find ./luci-theme-argon -type f -iname "*.css")
	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

# 晶晨宝盒
# git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
# sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/haiibo/OpenWrt'|g" package/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" package/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|ARMv8|ARMv8_PLUS|g" package/luci-app-amlogic/root/etc/config/amlogic

# SmartDNS
# git clone --depth=1 -b lede https://github.com/pymumu/luci-app-smartdns package/luci-app-smartdns
# git clone --depth=1 https://github.com/pymumu/openwrt-smartdns package/smartdns

# msd_lite
# git clone --depth=1 https://github.com/ximiTech/luci-app-msd_lite package/luci-app-msd_lite
# git clone --depth=1 https://github.com/ximiTech/msd_lite package/msd_lite

# MosDNS
# git clone --depth=1 https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns

# Alist
# git clone --depth=1 https://github.com/sbwml/luci-app-alist package/luci-app-alist

# DDNS.to
# git_sparse_clone main https://github.com/linkease/nas-packages-luci luci/luci-app-ddnsto
# git_sparse_clone master https://github.com/linkease/nas-packages network/services/ddnsto

# iStore
# git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui
# git_sparse_clone main https://github.com/linkease/istore luci

# 在线用户
git_sparse_clone main https://github.com/haiibo/packages luci-app-onliner
sed -i '$i uci set nlbwmon.@nlbwmon[0].refresh_interval=2s' package/lean/default-settings/files/zzz-default-settings
sed -i '$i uci commit nlbwmon' package/lean/default-settings/files/zzz-default-settings
chmod 755 package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh

# x86 型号只显示 CPU 型号
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore

# 修改本地时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 修改版本为编译日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by Haiibo/g" package/lean/default-settings/files/zzz-default-settings

# 修复 hostapd 报错
cp -f $GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch

# 修复 armv8 设备 xfsprogs 报错
# sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile

# 修改 Makefile
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# 取消主题默认设置
# find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

# 调整 V2ray服务器 到 VPN 菜单
# sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-v2ray-server/luasrc/controller/*.lua
# sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-v2ray-server/luasrc/model/cbi/v2ray_server/*.lua
# sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-v2ray-server/luasrc/view/v2ray_server/*.htm

./scripts/feeds update -a
./scripts/feeds install -a
