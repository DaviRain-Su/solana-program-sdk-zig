#!/bin/bash
# 安装 Solana 兼容的 Zig 编译器

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=== Installing Solana-compatible Zig compiler ==="
echo

# 设置版本和平台
SOLANA_VERSION="${SOLANA_ZIG_VERSION:-v1.47.0}"
PLATFORM=""
ABI=""

# 检测操作系统和架构
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# 转换架构名称
if [ "$ARCH" = "arm64" ]; then
    ARCH="aarch64"
fi

case "$OS" in
    linux)
        OS="linux"
        ABI="musl"
        ;;
    darwin)
        OS="macos"
        ABI="none"
        ;;
    mingw*|msys*|cygwin*)
        OS="windows"
        ABI="gnu"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

PLATFORM="${ARCH}-${OS}-${ABI}"
echo "Detected platform: $PLATFORM"

# 设置安装目录
INSTALL_DIR="$PROJECT_ROOT/solana-zig"
mkdir -p "$INSTALL_DIR"

# 下载 URL（基于 joncinque 的发布）
DOWNLOAD_URL="https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-${SOLANA_VERSION}/zig-${PLATFORM}.tar.bz2"

echo "Downloading from: $DOWNLOAD_URL"

# 下载和解压
cd "$INSTALL_DIR"
if command -v curl &> /dev/null; then
    curl -L -o zig.tar.bz2 "$DOWNLOAD_URL"
elif command -v wget &> /dev/null; then
    wget -O zig.tar.bz2 "$DOWNLOAD_URL"
else
    echo "Error: curl or wget not found"
    exit 1
fi

echo "Extracting..."
tar -xjf zig.tar.bz2 --strip-components=1
rm zig.tar.bz2

# 创建符号链接
ln -sf "$INSTALL_DIR/zig" "$PROJECT_ROOT/solana-zig-compiler"

# 验证安装
if [ -x "$INSTALL_DIR/zig" ]; then
    echo
    echo "✅ Solana-compatible Zig installed successfully!"
    echo "Location: $INSTALL_DIR"
    echo
    echo "To use it:"
    echo "  $INSTALL_DIR/zig build"
    echo "  or"
    echo "  ./solana-zig/zig build"
    echo
    "$INSTALL_DIR/zig" version
else
    echo "❌ Installation failed"
    exit 1
fi

# 创建便捷脚本
cat > "$PROJECT_ROOT/build-solana.sh" << 'EOF'
#!/bin/bash
# 使用 Solana Zig 构建程序

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
"$SCRIPT_DIR/solana-zig/zig" build "$@"
EOF
chmod +x "$PROJECT_ROOT/build-solana.sh"

echo
echo "Created build-solana.sh for convenience"
echo
echo "Next steps:"
echo "1. Update your build.zig to use Solana targets"
echo "2. Run: ./build-solana.sh"
echo "3. Deploy: solana program deploy zig-out/lib/program.so"