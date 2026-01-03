#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.88
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 注入 EMB-3531 硬件支持补丁 (317补丁)
# 我们将补丁放入通用目录，确保 5.10 或 5.15 内核都能尝试应用
mkdir -p target/linux/rockchip/patches-5.15/
[ -f ../317-rk3399-emb3531.patch ] && cp ../317-rk3399-emb3531.patch target/linux/rockchip/patches-5.15/

# 3. 注册板级支持 (补丁 212 逻辑)
# 这一步是为了让 "Norco EMB-3531" 出现在 make menuconfig 的型号选择列表里
cat <<EOF > target/linux/rockchip/patches-5.15/212-rk3399-emb3531-support.patch
--- a/arch/arm64/boot/dts/rockchip/Makefile
+++ b/arch/arm64/boot/dts/rockchip/Makefile
@@ -48,6 +48,7 @@ dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3399-evb.dtb
 dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3399-ficus.dtb
 dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3399-firefly.dtb
 dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3399-gru-bob.dtb
+dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3399-emb3531.dtb
 dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3399-gru-kevin.dtb
 EOF

# 4. 手动下载 dae 及其 LuCI 界面 (避开 Feed 报错)
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 5. 预设旁路由优化参数
{
    echo "CONFIG_BPF=y"
    echo "CONFIG_BPF_SYSCALL=y"
    echo "CONFIG_BPF_JIT=y"
    echo "CONFIG_IKCONFIG=y"
    echo "CONFIG_IKCONFIG_PROC=y"
    echo "CONFIG_PACKAGE_kmod-r8125=y"
    echo "CONFIG_PACKAGE_luci-app-dae=y"
    echo "CONFIG_PACKAGE_luci-app-smartdns=y"
} >> .config

# 6. 移除导致冲突的软件包
rm -rf package/feeds/luci/luci-app-nat64
