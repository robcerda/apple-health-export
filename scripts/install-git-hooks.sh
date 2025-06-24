#!/bin/bash

# Install git hooks for Health Exporter
# Run this once after cloning the repository

echo "🔧 Installing git hooks for Health Exporter..."

# Create pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Health Exporter pre-commit hook
# Runs security checks before allowing commits

echo "🔒 Running pre-commit security checks..."

# Run security check
if ! ./scripts/security-check.sh; then
    echo ""
    echo "❌ Pre-commit hook failed!"
    echo "Fix security issues before committing."
    echo ""
    echo "To skip this check (NOT RECOMMENDED):"
    echo "git commit --no-verify"
    exit 1
fi

echo "✅ Pre-commit checks passed!"
EOF

# Make hook executable
chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook installed!"
echo ""
echo "This hook will:"
echo "- Check for code signing certificates"
echo "- Scan for potential secrets in code"
echo "- Warn about large files"
echo "- Prevent accidental commits of sensitive data"
echo ""
echo "To bypass the hook (emergency only):"
echo "git commit --no-verify"