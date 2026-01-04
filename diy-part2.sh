#!/bin/bash

# 1. 基础配置：修改默认 IP
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【核心纠偏】彻底解决 Patch failed 报错
# 物理删除所有可能干扰 R4S 设备树的补丁
rm -f target/linux/rockchip/patches-5.15/100-rockchip-use-system-LED-for-OpenWrt.patch
rm -f target/linux/rockchip/patches-5.15/105-nanopi-r4s-sd-signalling.patch
rm -f target/linux/rockchip/patches-5.15/900-arm64-boot-add-dts-files.patch

# 3. 【核心注入】基于您提供的真实 DTB 基因改造 (使用 files 机制)
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

# 4. 【高能预警：物理重写镜像规则】这是解决 17MB 的最终绝杀
# 我们直接覆盖 armv8.mk，强行定义 R4S 必须产出 1024MB 的 COMBINED 镜像
# 绕过所有源码预设的限制
MK_FILE="target/linux/rockchip/image/armv8.mk"
echo '
define Device/friendlyarm_nanopi-r4s
  DEVICE_VENDOR := FriendlyElec
  DEVICE_MODEL := NanoPi R4S
  DEVICE_PACKAGES := kmod-r8125 kmod-usb-net-rtl8152
  $(Device/rk3399)
  IMAGE/combined-ext4.img.gz := grub-config | combined | append-metadata | gzip
  KERNEL_SIZE := 128M
endef
TARGET_DEVICES += friendlyarm_nanopi-r4s
' > $MK_FILE

# 5. 下载插件
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 6. 【配置强制锁定】
cat <<EOF > .config
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_friendlyarm_nanopi-r4s=y
CONFIG_PACKAGE_kmod-r8125=y
CONFIG_PACKAGE_luci-app-dae=y
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y
# 暴力开启磁盘镜像参数
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_IMAGE_EXT4_COMBINED=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

make defconfig
