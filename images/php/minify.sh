#!/bin/sh

set -e

# Function to get directory size in human-readable format
get_dir_size() {
    du -sh "$1" | cut -f1
}

# Directory to process (default to current directory if not provided)
TARGET_DIR="${1:-.}"
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

# Get number of CPU cores for parallel processing
PARALLEL_JOBS=$(nproc)

echo "Initial folder size: $(get_dir_size "$TARGET_DIR")"

# Process files and count them in one go
TOTAL_FILES=0
find "$TARGET_DIR" -type f -name "*.php" | tee /tmp/php_files_queue | wc -l | { read count; echo "Found $count PHP files to process"; }

# Process files in parallel
cat /tmp/php_files_queue | xargs -P "$PARALLEL_JOBS" -n 1 sh -c '
    file="$1"
    php -w "$file" > "$file.tmp" && mv "$file.tmp" "$file"
' --

rm -f /tmp/php_files_queue

echo "Final folder size: $(get_dir_size "$TARGET_DIR")"
echo "Minification complete!"
