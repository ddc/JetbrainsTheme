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
# Functions
# ============================================================================
write_gradle_properties() {
    echo "Writing settings into gradle.properties..."
    local since_build
    since_build="$(echo "$MIN_PLATFORM_VERSION" | sed -E 's/^20([0-9]{2})\.([0-9]+).*/\1\2/')"
    sed -i "s/^pluginVersion = .*/pluginVersion = ${VERSION}/" gradle.properties
    sed -i "s/^pluginSinceBuild = .*/pluginSinceBuild = ${since_build}/" gradle.properties
    sed -i "s/^platformVersion = .*/platformVersion = ${MIN_PLATFORM_VERSION}/" gradle.properties
    sed -i "s/^org.gradle.jvmargs = .*/org.gradle.jvmargs = ${GRADLE_BUILD_JVM_ARGS}/" gradle.properties
    echo "$WHATS_NEW" > .whats_new.html
    echo
}

update_changelog() {
    echo "Updating Changelog..."
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
    echo
}

format_kotlin() {
    if command -v ktlint &> /dev/null; then
        echo "Running ktlint..."
        ktlint --format "src/**/*.kt"
        echo
    fi
}

verify_plugin() {
    echo "Verifying plugin..."
    ./gradlew verifyPlugin 2>&1 | grep -E "IU-|IC-|PS-|Scheduled"
    echo
}

build_plugin() {
    echo "Building plugin..."
    ./gradlew buildPlugin
    echo
}

cleanup_build() {
    echo "Cleaning up build files..."
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

echo -e "\n\033[1;92m✔\033[0m Plugin: build/${ZIP_FILE}\n"
popd > /dev/null
