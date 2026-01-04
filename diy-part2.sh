#!/bin/bash

# 1. 基础配置
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【核心注入】基于工作固件的“基因改造”
# 我们不再盲目使用通用模板，而是基于您提供的 DTB 逻辑，强行覆盖内核的 R4S 定义
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p $DTS_DIR

cat <<EOF > $DTS_DIR/rk3399-nanopi-r4s.dts
/dts-v1/;
#include "rk3399-nanopi4.dtsi"

/ {
	model = "Norco EMB-3531 Final Fix";
	compatible = "norco,emb3531", "friendlyarm,nanopi-r4s", "rockchip,rk3399";

	/* 核心修复：注入这块主板缺失的 PCIe 供电节点 */
	vcc3v3_pcie: vcc3v3-pcie-regulator {
		compatible = "regulator-fixed";
		enable-active-high;
		gpio = <&gpio1 RK_PC1 GPIO_ACTIVE_HIGH>; /* GPIO1_C1: 关键供电引脚 */
		pinctrl-names = "default";
		pinctrl-0 = <&pcie_vcc3v3_en>;
		regulator-name = "vcc3v3_pcie";
		regulator-always-on;
		regulator-boot-on;
	};
};

&pcie0 {
	ep-gpios = <&gpio2 RK_PA4 GPIO_ACTIVE_HIGH>;
	vpcie3v3-supply = <&vcc3v3_pcie>; /* 强行关联供电 */
	max-link-speed = <1>; /* 锁定 Gen1 提高握手稳定性 */
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

# 3. 【暴力延时】通过 Patch 确保内核多等 10 倍时间 (解决 timeout)
mkdir -p target/linux/rockchip/patches-5.15/
cat <<EOF > target/linux/rockchip/patches-5.15/999-pcie-rockchip-timeout-fix.patch
--- a/drivers/pci/controller/pcie-rockchip-host.c
+++ b/drivers/pci/controller/pcie-rockchip-host.c
@@ -36,8 +36,8 @@
-#define RETRY_COUNT			10
-#define SLEEP_MS			100
+#define RETRY_COUNT			100
+#define SLEEP_MS			1000
EOF

# 4. 【强制配置】解决镜像大小和打包问题
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
# 锁定生成 1.2GB 全量磁盘镜像
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_IMAGE_EXT4_COMBINED=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

make defconfig
