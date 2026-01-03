#!/bin/bash

# 1. 修改默认 IP 为 192.168.1.88
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 注入 EMB-3531 硬件补丁
# 创建补丁目录（锁定内核 5.15 版本，这是 RK3399 目前最稳的版本）
mkdir -p target/linux/rockchip/patches-5.15/
cp ../317-rk3399-emb3531.patch target/linux/rockchip/patches-5.15/

# 3. 注册板级 Makefile (补丁 212 逻辑)
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

# 4. 强制开启 dae 运行所需的 eBPF 内核参数
{
    echo "CONFIG_BPF=y"
    echo "CONFIG_BPF_SYSCALL=y"
    echo "CONFIG_BPF_JIT=y"
    echo "CONFIG_IKCONFIG=y"
    echo "CONFIG_IKCONFIG_PROC=y"
} >> .config

# 5. 强制添加 2.5G 网卡驱动和旁路由必备插件
{
    echo "CONFIG_PACKAGE_kmod-r8125=y"
    echo "CONFIG_PACKAGE_luci-app-dae=y"
    echo "CONFIG_PACKAGE_luci-app-smartdns=y"
    echo "CONFIG_PACKAGE_luci-app-ttyd=y"
} >> .config

# 6. 删除可能冲突的 nat64 源码
rm -rf package/feeds/luci/luci-app-nat64
