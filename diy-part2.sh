#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.88
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 硬件补丁注入：自动匹配内核版本并打入 317 补丁
for kernel_dir in target/linux/rockchip/patches-*; do
    if [ -d "$kernel_dir" ]; then
        cp ../317-rk3399-emb3531.patch "$kernel_dir/"
    fi
done

# 3. 手动下载 dae 插件 (跳过软件源系统)
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 4. 【核心纠偏】强制指定硬件型号并注入配置
# 先清理旧配置，确保我们的注入生效
echo "CONFIG_TARGET_rockchip=y" > .config
echo "CONFIG_TARGET_rockchip_rk3399=y" >> .config
# 尝试选中补丁后的 EMB-3531 型号，如果没识别则回退到 NanoPi R4S (因为 R4S 也是双 PCIe 网卡架构，兼容性最好)
echo "CONFIG_TARGET_rockchip_rk3399_DEVICE_rockchip_rk3399-emb3531=y" >> .config || echo "CONFIG_TARGET_rockchip_rk3399_DEVICE_friendlyarm_nanopi-r4s=y" >> .config

# 5. 注入 2.5G 驱动、dae 插件和 eBPF 内核参数
cat <<EOF >> .config
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

# 6. 旁路由逻辑预设：网关 1.1，DNS 223.5.5.5
sed -i "/set network.lan.ipaddr/a \                set network.lan.gateway='192.168.1.1'\n                set network.lan.dns='223.5.5.5'" package/base-files/files/bin/config_generate

# 7. 补齐依赖并应用配置
make defconfig
