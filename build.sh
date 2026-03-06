#!/usr/bin/env bash
# ============================================================================
# Script to build the plugin
# DDC Softwares (daniel@ddcsoftwares.com)
# https://plugins.jetbrains.com/plugin/30414-ddc-theme
# ============================================================================

set -euo pipefail


# ============================================================================
# Plugin Settings
# ============================================================================
VERSION="1.0.7"
MIN_PLATFORM_VERSION="2025.3.3"
WHATS_NEW=$(cat <<'EOF'
<ul>
<li>Window > Layouts > DDC Window Layout</li>
<li>Settings > Editor > Code Style > DDC Code Style</li>
<li>Settings > Tools > DDC Theme (word highlighting, disabled by default)</li>
</ul>

EOF
)
# ============================================================================
JAVA_HOME="$HOME/Programs/java/jdk-21"
GRADLE_BUILD_JVM_ARGS="-Xmx2g"
# ============================================================================
export JAVA_HOME
cd "$(dirname "${BASH_SOURCE[0]}")"


# ============================================================================
# Functions
# ============================================================================
cleanup_build() {
    mv "build/distributions/${ZIP_FILE}" build
    rm -rf build/classes build/distributions build/generated build/instrumented \
           build/libs build/reports build/resources build/tmp build/kotlin \
           build/idea-sandbox .gradle .intellijPlatform .kotlin .whats_new.html \
           gradlew.bat
}

update_changelog() {
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


# ============================================================================
# Build
# ============================================================================

# Derive since-build from platform version (e.g. 2025.3.3 → 253)
SINCE_BUILD="$(echo "$MIN_PLATFORM_VERSION" | sed -E 's/^20([0-9]{2})\.([0-9]+).*/\1\2/')"

# Write settings into gradle.properties so Gradle picks them up
sed -i "s/^pluginVersion = .*/pluginVersion = ${VERSION}/" gradle.properties
sed -i "s/^pluginSinceBuild = .*/pluginSinceBuild = ${SINCE_BUILD}/" gradle.properties
sed -i "s/^platformVersion = .*/platformVersion = ${MIN_PLATFORM_VERSION}/" gradle.properties
sed -i "s/^org.gradle.jvmargs = .*/org.gradle.jvmargs = ${GRADLE_BUILD_JVM_ARGS}/" gradle.properties

# Write change notes for Gradle to inject into plugin.xml and in-IDE notification
echo "$WHATS_NEW" > .whats_new.html

# Update CHANGELOG.md with current version's "What's New"
update_changelog

# Verify Plugin against Jetbrains IDEs
if [[ "${1:-}" == "--verify" ]]; then
    echo "Verifying plugin..."
    ./gradlew verifyPlugin 2>&1 | grep -E "IU-|IC-|PS-|Scheduled"
    echo
fi

# Build Plugin
./gradlew buildPlugin

# Keep only the final zip in build directory
ZIP_FILE="DDC-Theme-${VERSION}.zip"
cleanup_build

# Display Success
echo
echo -e "\033[1;92m✔\033[0m Plugin: build/${ZIP_FILE}"
echo
