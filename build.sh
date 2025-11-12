#!/bin/sh

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 清理函数 - 删除核心 u-boot 文件
clean_build() {
    # 确保在脚本目录下执行
    cd "$SCRIPT_DIR"

    # 删除编译生成的板卡文件
    for target in re-ss-01 re-cs-02 re-cs-07 ax5-jdcloud; do
        if [ -f "uboot-ipq60xx-emmc-${target}-*.bin" ]; then
            rm "uboot-ipq60xx-emmc-${target}-*.bin"
        fi
    done
}

# 深度清理函数 - 清理所有生成文件
clean_all_build() {
    # 确保在脚本目录下执行
    cd "$SCRIPT_DIR"

    echo "根据 .gitignore 规则深度清理"
    if [ -d "${SCRIPT_DIR}/u-boot-2016" ]; then
        cd "${SCRIPT_DIR}/u-boot-2016"
        find . -type f \
            \( \
                -name '*.o' -o \
                -name '*.o.*' -o \
                -name '*.a' -o \
                -name '*.s' -o \
                -name '*.su' -o \
                -name '*.mod.c' -o \
                -name '*.i' -o \
                -name '*.lst' -o \
                -name '*.order' -o \
                -name '*.elf' -o \
                -name '*.swp' -o \
                -name '*.bin' -o \
                -name '*.patch' -o \
                -name '*.cfgtmp' -o \
                -name '*.exe' -o \
                -name 'MLO*' -o \
                -name 'SPL' -o \
                -name 'System.map' -o \
                -name 'LOG' -o \
                -name '*.orig' -o \
                -name '*~' -o \
                -name '#*#' -o \
                -name 'cscope.*' -o \
                -name 'tags' -o \
                -name 'ctags' -o \
                -name 'etags' -o \
                -name 'GPATH' -o \
                -name 'GRTAGS' -o \
                -name 'GSYMS' -o \
                -name 'GTAGS' \
            \) -delete
        rm -rf \
            .stgit-edit.txt \
            .gdb_history \
            arch/arm/dts/dtbtable.S \
            httpd/fsdata.c \
            scripts_mbn/mbn_tools.pyc \
            u-boot* \
            .config \
            include/config \
            include/generated
        # 返回脚本目录
        cd "$SCRIPT_DIR"
    fi
}

# 编译函数（包含清理）
compile_target_with_clean() {
    local target_name=$1
    local config_name=$2

    echo "编译目标: $target_name"

    # 编译前执行深度清理
    echo "编译前清理构建环境..."
    clean_all_build

    # 设置编译环境
    echo "设置编译环境"
    cd "${SCRIPT_DIR}/u-boot-2016/"
    . "${SCRIPT_DIR}/env.sh"

    echo "构建配置: $config_name"
    make ${config_name}_defconfig
    make V=s

    if [ $? -ne 0 ]; then
        echo "错误: 编译失败!"
        exit 1
    fi

    echo "Strip elf"
    arm-openwrt-linux-strip u-boot

    echo "转换 elf 到 mbn"
    python3 scripts_mbn/elftombn.py -f ./u-boot -o ./u-boot.mbn -v 6

    echo "复制 u-boot.mbn 到根目录"
    mv ./u-boot.mbn "${SCRIPT_DIR}/uboot-ipq60xx-emmc-${target_name}-"$UBOOT_VERSION".bin"

    echo "编译完成: $target_name"

    # 返回脚本目录
    cd "$SCRIPT_DIR"
}

# 帮助文档函数
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  clean                   删除核心 u-boot 文件"
    echo "  clean_all               深度清理所有生成文件"
    echo "  build_re-ss-01          编译 JDCloud AX1800 Pro (Arthur)"
    echo "  build_re-cs-02          编译 JDCloud AX6600 (Athena)"
    echo "  build_re-cs-07          编译 JDCloud ER1"
    echo "  build_ax5-jdcloud       编译 Redmi AX5 JDCloud"
    echo "  build_all               编译所有支持的板卡"
    echo "  help                    显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 build_re-ss-01       编译 Arthur 板卡"
    echo "  $0 build_all            编译所有板卡"
    echo "  $0 clean                清理生成文件"
}

# 主逻辑 - 使用 case 语句
case "$1" in
    "clean")
        clean_build
        echo "清理完成!"
        ;;

    "clean_all")
        clean_all_build
        echo "深度清理完成!"
        ;;

    "build_re-ss-01")
        compile_target_with_clean "re-ss-01" "ipq6018_jdcloud_re_ss_01"
        ;;

    "build_re-cs-02")
        compile_target_with_clean "re-cs-02" "ipq6018_jdcloud_re_cs_02"
        ;;

    "build_re-cs-07")
        compile_target_with_clean "re-cs-07" "ipq6018_jdcloud_re_cs_07"
        ;;

    "build_ax5-jdcloud")
        compile_target_with_clean "ax5-jdcloud" "ipq6018_redmi_ax5_jdcloud"
        ;;

    "build_all")
        echo "编译所有支持的板卡..."

        # 依次编译所有板卡，每个板卡编译前都清理
        compile_target_with_clean "re-ss-01" "ipq6018_jdcloud_re_ss_01"
        compile_target_with_clean "re-cs-02" "ipq6018_jdcloud_re_cs_02"
        compile_target_with_clean "re-cs-07" "ipq6018_jdcloud_re_cs_07"
        compile_target_with_clean "ax5-jdcloud" "ipq6018_redmi_ax5_jdcloud"

        echo "所有板卡编译完成!"
        ;;

    "help"|"")
        show_help
        ;;

    *)
        echo "错误: 未知选项 '$1'"
        echo "使用 '$0 help' 查看可用选项"
        exit 1
        ;;
esac

# 只有编译操作才显示完成消息
case "$1" in
    "build_re-ss-01"|"build_re-cs-02"|"build_re-cs-07"|"build_ax5-jdcloud"|"build_all")
        echo "全部完成!"
        ;;
esac
