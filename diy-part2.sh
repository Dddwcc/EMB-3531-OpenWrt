#!/bin/bash

# 1. 基础配置
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【绝杀补丁冲突】物理删除所有可能导致中断的 R4S 专有补丁
rm -f target/linux/rockchip/patches-5.15/*nanopi-r4s*
rm -f target/linux/rockchip/patches-5.15/*LED*

# 3. 【核心注入】基于您 DTB 数据的基因改造
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p $DTS_DIR
cat <<EOF > $DTS_DIR/rk3399-nanopi-r4s.dts
/dts-v1/;
#include "rk3399-nanopi4.dtsi"
/ {
	model = "Norco EMB-3531 Final Fix";
	compatible = "norco,emb3531", "friendlyarm,nanopi-r4s", "rockchip,rk3399";
	vcc3v3_pcie: vcc3v3-pcie-regulator {
		compatible = "regulator-fixed";
		enable-active-high;
		gpio = <&gpio1 RK_PC1 GPIO_ACTIVE_HIGH>;
		pinctrl-names = "default";
		pinctrl-0 = <&pcie_vcc3v3_en>;
		regulator-name = "vcc3v3_pcie";
		regulator-always-on;
		regulator-boot-on;
	};
};
&pcie0 {
	ep-gpios = <&gpio2 RK_PA4 GPIO_ACTIVE_HIGH>;
	vpcie3v3-supply = <&vcc3v3_pcie>;
	max-link-speed = <1>;
	status = "okay";
};
EOF

# 4. 【核心保险】重写打包规则，强制 1.14GB 磁盘镜像输出
# 这里我们直接重新定义 R4S 的镜像规则，确保它一定产生 combined-ext4.img.gz
echo '
define Device/friendlyarm_nanopi-r4s
  DEVICE_VENDOR := FriendlyElec
  DEVICE_MODEL := NanoPi R4S
  DEVICE_PACKAGES := kmod-r8125 uboot-rockchip-rk3399
  \$(Device/rk3399)
  IMAGE/combined-ext4.img.gz := grub-config | combined | append-metadata | gzip
endef
TARGET_DEVICES := friendlyarm_nanopi-r4s
' > target/linux/rockchip/image/armv8.mk

# 5. 【配置锁定】注入所有的核心依赖包
# 必须先执行 make defconfig 之前写入
cat <<EOF > .config
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_friendlyarm_nanopi-r4s=y
CONFIG_PACKAGE_uboot-rockchip-rk3399=y
CONFIG_PACKAGE_kmod-r8125=y
CONFIG_PACKAGE_luci-app-dae=y
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_IMAGE_EXT4_COMBINED=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

# 6. 下载插件并完成配置
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 7. 应用配置并补全依赖
make defconfig
