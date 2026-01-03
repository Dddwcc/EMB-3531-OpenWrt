#!/bin/bash

# 1. 基础配置：修改 IP
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【核心注入】狸猫换太子：将 EMB-3531 定义强行写入通用 EVB 模板
# 这是确保镜像能生成、网卡能点亮的最稳路径
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p $DTS_DIR
cat <<EOF > $DTS_DIR/rk3399-evb.dts
/dts-v1/;
#include "rk3399.dtsi"
#include "rk3399-opp.dtsi"
/ {
	model = "Norco EMB-3531 Universal";
	compatible = "norco,emb3531", "rockchip,rk3399";
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
	pinctrl-names = "default";
	pinctrl-0 = <&pcie_clkreqnb_cpm>;
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
&sdhci { bus-width = <8>; mmc-hs400-1_8v; mmc-hs400-enhanced-strobe; non-removable; status = "okay"; };
EOF

# 3. 【暴力延时】修改驱动源码，将 100ms 超时改成 1000ms
# 这一步是为了解决您之前看到的 "gen1 timeout" 报错
mkdir -p target/linux/rockchip/
echo 'sed -i "s/RETRY_COUNT 10/RETRY_COUNT 100/g" drivers/pci/controller/pcie-rockchip-host.c' > target/linux/rockchip/hooks.sh
echo 'sed -i "s/msleep(100)/msleep(1000)/g" drivers/pci/controller/pcie-rockchip-host.c' >> target/linux/rockchip/hooks.sh

# 4. 手动克隆插件
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 5. 【盲编配置】锁定全量镜像打包 (Combined) 
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
# 核心镜像参数：确保解压后大于 1GB
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_IMAGE_EXT4_COMBINED=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

# 6. 旁路由逻辑
sed -i "/set network.lan.ipaddr/a \                set network.lan.gateway='192.168.1.1'\n                set network.lan.dns='223.5.5.5'" package/base-files/files/bin/config_generate

make defconfig
