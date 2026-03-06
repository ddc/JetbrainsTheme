#!/usr/bin/env bash
# ============================================================================
# Automated script to build the plugin and register changes on the changelog file
# DDC Softwares (daniel@ddcsoftwares.com)
# https://plugins.jetbrains.com/plugin/30414-ddc-theme
# ============================================================================
set -euo pipefail


# ============================================================================
# Variables
# ============================================================================
VERSION="1.0.7"
MIN_PLATFORM_VERSION="2025.3.3"
WHATS_NEW=$(cat <<'EOF'
<ul>
<li>Changed both themes to have 'Dark' in their names</li>
<li>Window > Layouts > DDC Window Layout</li>
<li>Settings > Editor > Code Style > DDC Code Style</li>
<li>Settings > Tools > DDC Theme (word highlighting, disabled by default)</li>
</ul>

EOF
)
# ============================================================================
JAVA_HOME="$HOME/Programs/java/jdk-21"
GRADLE_BUILD_JVM_ARGS="-Xmx2g"
pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null
export JAVA_HOME
ZIP_FILE="DDC-Theme-${VERSION}.zip"
# ============================================================================
BLUE="\033[1;94m"
GREEN="\033[1;92m"
NC="\033[0m"
log_action() { echo -e "${BLUE}➜ [ACTION]${NC} $*"; }
log_success() { echo -e "${GREEN}✓ [SUCCESS]${NC} $*"; }
echo


# ============================================================================
# Functions
# ============================================================================
write_gradle_properties() {
    log_action "Writing settings into gradle.properties..."
    local since_build
    since_build="$(echo "$MIN_PLATFORM_VERSION" | sed -E 's/^20([0-9]{2})\.([0-9]+).*/\1\2/')"
    sed -i "s/^pluginVersion = .*/pluginVersion = ${VERSION}/" gradle.properties
    sed -i "s/^pluginSinceBuild = .*/pluginSinceBuild = ${since_build}/" gradle.properties
    sed -i "s/^platformVersion = .*/platformVersion = ${MIN_PLATFORM_VERSION}/" gradle.properties
    sed -i "s/^org.gradle.jvmargs = .*/org.gradle.jvmargs = ${GRADLE_BUILD_JVM_ARGS}/" gradle.properties
    echo "$WHATS_NEW" > .whats_new.html
}

update_changelog() {
    log_action "Updating Changelog..."
    local items after
    items="$(echo "$WHATS_NEW" | sed -n 's|<li>\(.*\)</li>|- \1|p')"
    if [[ -f CHANGELOG.md ]] && grep -q "## v${VERSION}" CHANGELOG.md; then
        after="$(sed -n "/^## v${VERSION}$/,\${ /^## v${VERSION}$/!p; }" CHANGELOG.md | sed -n '/^## v/,$p')"
        { echo "# Changelog"; echo; echo "## v${VERSION}"; echo "$items"; echo; if [[ -n "$after" ]]; then echo "$after"; fi } > CHANGELOG.tmp
        mv CHANGELOG.tmp CHANGELOG.md
    elif [[ -f CHANGELOG.md ]]; then
        { echo "# Changelog"; echo; echo "## v${VERSION}"; echo "$items"; echo; tail -n +2 CHANGELOG.md; } > CHANGELOG.tmp
        mv CHANGELOG.tmp CHANGELOG.md
    else
        { echo "# Changelog"; echo; echo "## v${VERSION}"; echo "$items"; echo; } > CHANGELOG.md
    fi
}

format_kotlin() {
    if command -v ktlint &> /dev/null; then
        log_action "Running ktlint..."
        ktlint --format "src/**/*.kt"
    fi
}

verify_plugin() {
    log_action "Verifying plugin..."
    ./gradlew verifyPlugin 2>&1 | grep -E "IU-|IC-|PS-|Scheduled"
}

build_plugin() {
    log_action "Building plugin..."
    ./gradlew buildPlugin
}

cleanup_build() {
    log_action "Cleaning up build files..."
    mv "build/distributions/${ZIP_FILE}" build
    rm -rf build/classes build/distributions build/generated build/instrumented \
           build/libs build/reports build/resources build/tmp build/kotlin \
           build/idea-sandbox .gradle .intellijPlatform .kotlin .whats_new.html \
           gradlew.bat
    echo
}


# ============================================================================
# Build
# ============================================================================
write_gradle_properties
update_changelog
format_kotlin
verify_plugin
build_plugin
cleanup_build

log_success "Plugin: ./build/${ZIP_FILE}"
popd > /dev/null
