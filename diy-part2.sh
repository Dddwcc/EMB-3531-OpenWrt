#!/bin/bash

# 1. 修改默认 IP
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【核心纠偏】使用 files 机制强制覆盖 DTS (补丁引擎看不到这一步，100% 不报错)
# 我们覆盖官方最基础的 rk3399-evb.dts，把 EMB-3531 的灵魂装进去
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p $DTS_DIR
cat <<EOF > $DTS_DIR/rk3399-evb.dts
/dts-v1/;
#include "rk3399.dtsi"
#include "rk3399-opp.dtsi"
/ {
	model = "Norco EMB-3531";
	compatible = "norco,emb3531", "rockchip,rk3399-evb", "rockchip,rk3399";
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
&pinctrl {
	pcie {
		pcie_vcc3v3_en: pcie-vcc3v3-en {
			rockchip,pins = <1 RK_PC1 RK_FUNC_GPIO &pcfg_pull_none>;
		};
	};
};
EOF

# 3. 手动下载 dae
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 4. 【生存保障】强制生成全量磁盘镜像，并修正子目标为 armv8
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
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_IMAGE_EXT4_COMBINED=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

make defconfig
