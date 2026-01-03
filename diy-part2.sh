#!/bin/bash

# 1. 修改默认 IP 为 192.168.1.88
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 注入 EMB-3531 硬件支持补丁 (317补丁)
mkdir -p target/linux/rockchip/patches-5.15/
[ -f ../317-rk3399-emb3531.patch ] && cp ../317-rk3399-emb3531.patch target/linux/rockchip/patches-5.15/

# 3. 手动下载 dae 及其 LuCI 插件 (跳过软件源系统，防止报错)
# 下载 dae 核心包
git clone https://github.com/dae-universe/dae package/dae
# 下载 dae LuCI 界面
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

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
} >> .config

# 6. 删除之前导致编译崩溃的 nat64 (如存在)
rm -rf package/feeds/luci/luci-app-nat64
