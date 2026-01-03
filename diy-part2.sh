#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.88
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 硬件补丁注入：自动匹配内核版本并打入 317 补丁 (2.5G 网卡驱动的核心)
for kernel_dir in target/linux/rockchip/patches-*; do
    if [ -d "$kernel_dir" ]; then
        cp ../317-rk3399-emb3531.patch "$kernel_dir/"
    fi
done

# 3. 注册板级支持 (补丁 212 逻辑)
find target/linux/rockchip/ -name "Makefile" | xargs sed -i '/rk3399-gru-bob.dtb/a \	rk3399-emb3531.dtb \\' 2>/dev/null || true

# 4. 手动克隆 dae 插件 (由于 SSH 无法连接，我们直接在这里下载)
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 5. 【核心步骤】强制写入编译配置 (即替代 make menuconfig)
# 针对 RK3399 和 EMB-3531 的硬件定义
cat <<EOF >> .config
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_rk3399=y
CONFIG_TARGET_rockchip_rk3399_DEVICE_rockchip_rk3399-evb=y
CONFIG_TARGET_MULTI_PROFILE=y
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
CONFIG_STRIP_KERNEL_EXPORTS=n
EOF

# 6. 旁路由逻辑预设：网关 1.1，DNS 223.5.5.5
sed -i "/set network.lan.ipaddr/a \                set network.lan.gateway='192.168.1.1'\n                set network.lan.dns='223.5.5.5'" package/base-files/files/bin/config_generate

# 7. 自动修复配置依赖
make defconfig
