#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.88
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 硬件补丁注入：适配 23.05 的内核版本
# 23.05 通常使用 5.15 内核，我们将补丁放入对应目录
mkdir -p target/linux/rockchip/patches-5.15/
[ -f ../317-rk3399-emb3531.patch ] && cp ../317-rk3399-emb3531.patch target/linux/rockchip/patches-5.15/

# 3. 注册板级支持 (补丁 212 逻辑的自动化实现)
# 强制在 Makefile 中加入 emb3531 设备树编译目标
find target/linux/rockchip/ -name "Makefile" | xargs sed -i '/rk3399-gru-bob.dtb/a \	rk3399-emb3531.dtb \\' 2>/dev/null || true

# 4. 手动克隆 dae 插件 (官方最新版)
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 5. 盲编配置注入 (针对 23.05 稳定版优化)
cat <<EOF > .config
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_rk3399=y
CONFIG_TARGET_rockchip_rk3399_DEVICE_rockchip_rk3399-evb=y
CONFIG_PACKAGE_kmod-r8125=y
CONFIG_PACKAGE_luci-app-dae=y
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y
EOF

# 6. 旁路由逻辑预设：网关 1.1，DNS 223.5.5.5
sed -i "/set network.lan.ipaddr/a \                set network.lan.gateway='192.168.1.1'\n                set network.lan.dns='223.5.5.5'" package/base-files/files/bin/config_generate

# 7. 应用配置
make defconfig
