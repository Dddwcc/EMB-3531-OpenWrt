#!/bin/bash

# 1. 基础配置
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【核心纠偏】彻底解决 16MB 问题：伪装成 NanoPi R4S (它的打包规则最全)
# 我们不再注册新名字，直接用 R4S 的壳子装 EMB-3531 的内核定义
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p $DTS_DIR
cat <<EOF > $DTS_DIR/rk3399-nanopi-r4s.dts
/dts-v1/;
#include "rk3399-nanopi4.dtsi"
/ {
	model = "Norco EMB-3531";
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

# 3. 【暴力破解】解决 PCIe Timeout
# 不再通过 patch 文件，直接在编译前夕通过 hooks.sh 用 sed 修改内核驱动源码
# 这种方法 100% 避开了补丁路径错误的问题
mkdir -p target/linux/rockchip/
echo 'sed -i "s/RETRY_COUNT 10/RETRY_COUNT 100/g" drivers/pci/controller/pcie-rockchip-host.c' > target/linux/rockchip/hooks.sh
echo 'sed -i "s/msleep(100)/msleep(1000)/g" drivers/pci/controller/pcie-rockchip-host.c' >> target/linux/rockchip/hooks.sh

# 4. 强制锁定全量镜像参数
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
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_IMAGE_EXT4_COMBINED=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

make defconfig
