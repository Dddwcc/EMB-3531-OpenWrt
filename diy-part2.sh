#!/bin/bash

# 1. 修正 IP 地址
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【核心修复】强制删除导致编译报错的内置 LED 补丁
# 这个补丁在 23.05 分支中经常与自定义 DTS 产生冲突，删掉它不影响启动
rm -f target/linux/rockchip/patches-5.15/100-rockchip-use-system-LED-for-OpenWrt.patch

# 3. 注入 PCIe 延时补丁 (解决网卡 timeout，改用 sed 直接修改源补丁，最稳)
# 寻找内核中已有的 pcie 补丁并强行修改其数值
find target/linux/rockchip/patches-5.15/ -name "*.patch" | xargs sed -i 's/RETRY_COUNT 10/RETRY_COUNT 100/g' 2>/dev/null
find target/linux/rockchip/patches-5.15/ -name "*.patch" | xargs sed -i 's/msleep(100)/msleep(1000)/g' 2>/dev/null

# 4. 强制锁定“通用开发板”配置，生成 1.1GB 的 Combined 磁盘镜像
cat <<EOF > .config
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_rockchip_rk3399-evb=y
CONFIG_PACKAGE_kmod-r8125=y
CONFIG_PACKAGE_luci-app-dae=y
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y

# 核心：确保生成全量磁盘镜像
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_IMAGE_EXT4_COMBINED=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

# 5. 下载插件
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 6. 应用配置
make defconfig
