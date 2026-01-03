#!/bin/bash

# 1. 基础配置：修改 IP
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【核心注入】伪装成 NanoPi R4S (确保生成 1GB+ 镜像)
# 理由：R4S 是双网口 RK3399，它的打包脚本最成熟，100% 生成 combined-ext4.img.gz
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p $DTS_DIR
cat <<EOF > $DTS_DIR/rk3399-nanopi-r4s.dts
/dts-v1/;
#include "rk3399-nanopi4.dtsi"
/ {
	model = "Norco EMB-3531 Final";
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

# 3. 【暴力延时补丁】解决 gen1 timeout (唯一的正确打法)
# 我们手动构造一个完全符合 Linux 内核标准的 .patch 文件并放入 patches 目录
PATCH_DIR="target/linux/rockchip/patches-5.15"
mkdir -p $PATCH_DIR
cat <<EOF > $PATCH_DIR/999-pcie-rockchip-timeout-fix.patch
--- a/drivers/pci/controller/pcie-rockchip-host.c
+++ b/drivers/pci/controller/pcie-rockchip-host.c
@@ -36,2 +36,2 @@
-#define RETRY_COUNT			10
-#define SLEEP_MS			100
+#define RETRY_COUNT			100
+#define SLEEP_MS			1000
EOF

# 4. 下载 dae 插件
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 5. 【配置锁定】强制生成 Combined 镜像与 eBPF 参数
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
# 确保生成 1GB 以上磁盘镜像
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_IMAGE_EXT4_COMBINED=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

make defconfig
