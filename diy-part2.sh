#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.88
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 硬件补丁注入：自动匹配内核版本并打入 317 补丁
for kernel_dir in target/linux/rockchip/patches-*; do
    if [ -d "$kernel_dir" ]; then
        cp ../317-rk3399-emb3531.patch "$kernel_dir/"
    fi
done

# 3. 注册板级 Makefile (补丁 212 逻辑)
find target/linux/rockchip/ -name "Makefile" | xargs sed -i '/rk3399-gru-bob.dtb/a \	rk3399-emb3531.dtb \\' 2>/dev/null || true

# 4. 手动克隆 dae 插件 (跳过 Feed 系统，解决报错)
# 先删除可能存在的冲突文件夹
rm -rf package/dae package/luci-app-dae
# 克隆官方最新源码到 package 目录
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 5. 强制开启 dae 运行所需的 eBPF/BTF 内核参数
{
    echo "CONFIG_DEBUG_INFO_BTF=y"
    echo "CONFIG_BPF=y"
    echo "CONFIG_BPF_SYSCALL=y"
    echo "CONFIG_BPF_JIT=y"
    echo "CONFIG_IKCONFIG=y"
    echo "CONFIG_IKCONFIG_PROC=y"
} >> .config

# 6. 强制添加驱动与核心插件勾选
{
    echo "CONFIG_PACKAGE_kmod-r8125=y"
    echo "CONFIG_PACKAGE_luci-app-dae=y"
    echo "CONFIG_PACKAGE_luci-app-smartdns=y"
} >> .config

# 7. 旁路由逻辑预设
sed -i "/set network.lan.ipaddr/a \                set network.lan.gateway='192.168.1.1'\n                set network.lan.dns='223.5.5.5'" package/base-files/files/bin/config_generate
