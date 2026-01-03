#!/bin/bash

# 1. 基础网络配置 (旁路由 IP 1.88)
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 【核心修复】创建内核源码覆盖目录并注入 DTS (彻底解决 Error 1)
# 这一步直接生成 EMB-3531 的硬件描述文件，跳过补丁引擎
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p $DTS_DIR

cat <<EOF > $DTS_DIR/rk3399-emb3531.dts
/dts-v1/;
#include "rk3399.dtsi"
#include "rk3399-opp.dtsi"

/ {
	model = "Norco EMB-3531";
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
	status = "okay";
};

&pinctrl {
	pcie {
		pcie_vcc3v3_en: pcie-vcc3v3-en {
			rockchip,pins = <1 RK_PC1 RK_FUNC_GPIO &pcfg_pull_none>;
		};
	};
};

&sdhci {
	bus-width = <8>;
	mmc-hs400-1_8v;
	mmc-hs400-enhanced-strobe;
	non-removable;
	status = "okay";
};
EOF

# 3. 强制在内核 Makefile 中注册该板子
find target/linux/rockchip/ -name "Makefile" | xargs sed -i '/rk3399-ficus.dtb/a \	rk3399-emb3531.dtb \\' 2>/dev/null || true

# 4. 手动克隆 dae 插件
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 5. 【盲编配置注入】强制指定型号、2.5G 驱动及 eBPF 参数
cat <<EOF > .config
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_rk3399=y
CONFIG_TARGET_rockchip_rk3399_DEVICE_rockchip_rk3399-emb3531=y
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

# 6. 旁路由逻辑预设：设置网关 1.1，DNS 223.5.5.5
sed -i "/set network.lan.ipaddr/a \                set network.lan.gateway='192.168.1.1'\n                set network.lan.dns='223.5.5.5'" package/base-files/files/bin/config_generate

# 7. 应用配置
make defconfig
