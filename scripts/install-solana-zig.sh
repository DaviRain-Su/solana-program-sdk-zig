#!/bin/bash
# 安装 Solana 兼容的 Zig 编译器

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=== Installing Solana-compatible Zig compiler ==="
echo

# 设置版本和平台
ZIG_VERSION="0.14.0-dev.solana.1"
PLATFORM=""

# 检测操作系统和架构
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
    linux)
        case "$ARCH" in
            x86_64) PLATFORM="x86_64-linux-gnu" ;;
            aarch64) PLATFORM="aarch64-linux-gnu" ;;
            *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        ;;
    darwin)
        case "$ARCH" in
            x86_64) PLATFORM="x86_64-macos-none" ;;
            arm64) PLATFORM="aarch64-macos-none" ;;
            *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "Detected platform: $PLATFORM"

# 设置安装目录
INSTALL_DIR="$PROJECT_ROOT/solana-zig"
mkdir -p "$INSTALL_DIR"

# 下载 URL（基于 joncinque 的发布）
DOWNLOAD_URL="https://github.com/joncinque/solana-zig-bootstrap/releases/download/v$ZIG_VERSION/zig-$PLATFORM-$ZIG_VERSION.tar.xz"

echo "Downloading from: $DOWNLOAD_URL"

# 下载和解压
cd "$INSTALL_DIR"
if command -v curl &> /dev/null; then
    curl -L -o zig.tar.xz "$DOWNLOAD_URL"
elif command -v wget &> /dev/null; then
    wget -O zig.tar.xz "$DOWNLOAD_URL"
else
    echo "Error: curl or wget not found"
    exit 1
fi

echo "Extracting..."
tar -xf zig.tar.xz --strip-components=1
rm zig.tar.xz

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