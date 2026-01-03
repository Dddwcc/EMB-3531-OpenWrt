#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.88
sed -i 's/192.168.1.1/192.168.1.88/g' package/base-files/files/bin/config_generate

# 2. 硬件补丁注入：自动匹配内核版本并打入 317 补丁
for kernel_dir in target/linux/rockchip/patches-*; do
    if [ -d "$kernel_dir" ]; then
        cp ../317-rk3399-emb3531.patch "$kernel_dir/"
    fi
done

# 3. 手动下载 dae 插件 (跳过软件源系统，防止报错)
rm -rf package/dae package/luci-app-dae
git clone https://github.com/dae-universe/dae package/dae
git clone https://github.com/dae-universe/luci-app-dae package/luci-app-dae

# 4. 【核心保险】在镜像生成脚本中强制注册 EMB-3531 型号
# 这样即使不点 menuconfig，编译器也能通过 .config 找到对应的镜像打包规则
if [ -f target/linux/rockchip/image/rk3399.mk ]; then
    sed -i '/define Device\/rockchip_rk3399-evb/,/endef/ { /endef/ a\
\
define Device/rockchip_rk3399-emb3531\
  DEVICE_VENDOR := Norco\
  DEVICE_MODEL := EMB-3531\
  $(Device/rk3399)\
endef\
TARGET_DEVICES += rockchip_rk3399-emb3531
    }' target/linux/rockchip/image/rk3399.mk
fi

# 5. 【盲编配置注入】强制指定硬件型号、2.5G 驱动和 dae 插件
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

# 6. 旁路由逻辑预设：网关 1.1，DNS 223.5.5.5
sed -i "/set network.lan.ipaddr/a \                set network.lan.gateway='192.168.1.1'\n                set network.lan.dns='223.5.5.5'" package/base-files/files/bin/config_generate

# 7. 应用并补齐配置
make defconfig
