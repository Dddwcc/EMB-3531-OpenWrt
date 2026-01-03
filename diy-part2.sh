#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.88
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 硬件补丁注入：自动匹配内核版本并打入 317 补丁
# 这确保了 RTL8125B 2.5G 网卡在 Norco 板子上的供电和时序正确
for kernel_dir in target/linux/rockchip/patches-*; do
    if [ -d "$kernel_dir" ]; then
        cp ../317-rk3399-emb3531.patch "$kernel_dir/"
        echo "Successfully copied EMB-3531 patch to $kernel_dir"
    fi
done

# 3. 注册板级 Makefile (补丁 212 逻辑)
# 遍历所有可能的内核路径进行注册，防止版本升级导致失效
find target/linux/rockchip/ -name "Makefile" | xargs sed -i '/rk3399-gru-bob.dtb/a \	rk3399-emb3531.dtb \\' 2>/dev/null || true

# 4. 强制开启 dae 运行所需的 eBPF/BTF 内核参数 (ImmortalWrt 核心优化)
{
    echo "CONFIG_DEBUG_INFO_BTF=y"
    echo "CONFIG_BPF=y"
    echo "CONFIG_BPF_SYSCALL=y"
    echo "CONFIG_BPF_JIT=y"
    echo "CONFIG_IKCONFIG=y"
    echo "CONFIG_IKCONFIG_PROC=y"
    echo "CONFIG_NET_CLS_BPF=y"
    echo "CONFIG_NET_ACT_BPF=y"
} >> .config

# 5. 强制添加驱动与核心插件
{
    echo "CONFIG_PACKAGE_kmod-r8125=y"
    echo "CONFIG_PACKAGE_luci-app-dae=y"
    echo "CONFIG_PACKAGE_luci-app-smartdns=y"
    echo "CONFIG_PACKAGE_luci-app-ttyd=y"
} >> .config

# 6. 旁路由逻辑预设：设置默认网关和 DNS（防止刷机后无法联网下插件）
# 这一步会直接把网关写进预设，让您刷机即用
sed -i "/set network.lan.ipaddr/a \                set network.lan.gateway='192.168.1.1'\n                set network.lan.dns='223.5.5.5'" package/base-files/files/bin/config_generate
