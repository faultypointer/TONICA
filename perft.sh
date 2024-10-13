# Ensure the correct usage
if [ $# -lt 2 ]; then
    echo "Usage: ./script.sh <FEN> <DEPTH>"
    exit 1
fi

# Define the path to your compiled binary
BINARY="./zig-out/bin/tonica"

# Check if the binary exists
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary '$BINARY' not found."
    exit 1
fi

# Run the binary with the provided arguments
"$BINARY" "$1" "$2"
