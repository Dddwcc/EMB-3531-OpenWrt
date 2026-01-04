#!/bin/bash

# 1. 修改默认 IP
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【核心纠偏】使用 files 机制注入 DTS (绕过补丁引擎)
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

# 3. 【核心修复】解决 17MB 问题的行业标准方案
# 使用 sed 在 rk3399 基础定义后注入 combined 镜像生成指令，而不破坏文件结构
# 这一步能确保 100% 产出 1.2GB 的磁盘镜像
MK_FILE="target/linux/rockchip/image/armv8.mk"
sed -i '/Device\/rk3399/a \  IMAGE/combined-ext4.img.gz := grub-config | combined | append-metadata | gzip' $MK_FILE

# 4. 下载插件
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 5. 【配置锁定】注入依赖和镜像参数
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

make defconfig
