#!/bin/bash

# verify-env.sh - Verification script for quadlet environment file setup

set -e

PROJ_PATH="$(cd "$(dirname "$0")/.." && pwd)"
ENV_PATH="$PROJ_PATH/.env"
QUADLET_DIR="$PROJ_PATH/quadlet"

echo "🔍 Verifying Archon quadlet environment setup..."
echo "Project root: $PROJ_PATH"
echo "Environment file: $ENV_PATH"
echo

# Check if .env file exists
if [[ ! -f "$ENV_PATH" ]]; then
    echo "❌ Environment file not found: $ENV_PATH"
    echo
    echo "📝 To fix this:"
    echo "1. Copy the template: cp $QUADLET_DIR/env.defaults $ENV_PATH"
    echo "2. Edit $ENV_PATH with your actual values"
    exit 1
fi

echo "✅ Environment file exists: $ENV_PATH"

# Check for required variables
required_vars=(
    "SUPABASE_URL"
    "SUPABASE_SERVICE_KEY"
    "ARCHON_SERVER_PORT"
    "ARCHON_MCP_PORT"
    "ARCHON_AGENTS_PORT"
    "ARCHON_UI_PORT"
    "ARCHON_DOCS_PORT"
    "LOG_LEVEL"
    "SERVICE_DISCOVERY_MODE"
)

missing_vars=()
placeholder_vars=()

echo
echo "🔍 Checking required environment variables..."

for var in "${required_vars[@]}"; do
    if grep -q "^$var=" "$ENV_PATH"; then
        value=$(grep "^$var=" "$ENV_PATH" | cut -d'=' -f2- | tr -d '"')
        if [[ -z "$value" || "$value" == "your-"* || "$value" == "https://your-"* ]]; then
            placeholder_vars+=("$var")
            echo "⚠️  $var is set but contains placeholder value"
        else
            echo "✅ $var is configured"
        fi
    else
        missing_vars+=("$var")
        echo "❌ $var is missing"
    fi
done

# Check quadlet files for correct EnvironmentFile paths
echo
echo "🔍 Checking quadlet container files..."

container_files=(
    "archon-server.container"
    "archon-frontend.container"
    "archon-mcp.container"
    "archon-agents.container"
    "archon-docs.container"
)

incorrect_paths=()

for file in "${container_files[@]}"; do
    filepath="$QUADLET_DIR/$file"
    if [[ -f "$filepath" ]]; then
        if grep -q "EnvironmentFile=$ENV_PATH" "$filepath"; then
            echo "✅ $file has correct EnvironmentFile path"
        else
            incorrect_paths+=("$file")
            current_path=$(grep "EnvironmentFile=" "$filepath" | cut -d'=' -f2- || echo "not found")
            echo "❌ $file has incorrect path: $current_path"
        fi
    else
        echo "⚠️  $file not found"
    fi
done

# Check build files exist
echo
echo "🔍 Checking quadlet build files..."

build_files=(
    "archon-server.build"
    "archon-frontend.build"
    "archon-mcp.build"
    "archon-agents.build"
    "archon-docs.build"
)

missing_builds=()

for file in "${build_files[@]}"; do
    filepath="$QUADLET_DIR/$file"
    if [[ -f "$filepath" ]]; then
        echo "✅ $file exists"
    else
        missing_builds+=("$file")
        echo "❌ $file not found"
    fi
done

# Summary
echo
echo "📊 Summary:"

if [[ ${#missing_vars[@]} -eq 0 && ${#placeholder_vars[@]} -eq 0 && ${#incorrect_paths[@]} -eq 0 && ${#missing_builds[@]} -eq 0 ]]; then
    echo "🎉 All checks passed! Your quadlet environment is properly configured."
    exit 0
fi

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "❌ Missing variables: ${missing_vars[*]}"
    echo "   Add these to $ENV_PATH"
fi

if [[ ${#placeholder_vars[@]} -gt 0 ]]; then
    echo "⚠️  Placeholder variables: ${placeholder_vars[*]}"
    echo "   Update these with your actual values in $ENV_PATH"
fi

if [[ ${#incorrect_paths[@]} -gt 0 ]]; then
    echo "❌ Incorrect paths in: ${incorrect_paths[*]}"
    echo "   Run: sed -i 's|EnvironmentFile=.*|EnvironmentFile=$ENV_PATH|g' $QUADLET_DIR/*.container"
fi

if [[ ${#missing_builds[@]} -gt 0 ]]; then
    echo "❌ Missing build files: ${missing_builds[*]}"
    echo "   These are required for building container images"
fi

echo
echo "📝 Next steps:"
echo "1. Update your .env file with the correct values"
echo "2. Ensure all quadlet files point to: $ENV_PATH"
echo "3. Verify all .build files exist for image building"
echo "4. Run this script again to verify"

exit 1
