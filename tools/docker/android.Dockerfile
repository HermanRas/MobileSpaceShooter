# The Android build image: JDK 17, the Android SDK (platform-tools for adb, build-tools for
# apksigner), and Godot's Android export templates. Godot itself is NOT in the image;
# tools/android.sh mounts the pinned binary read-only.
#
# Building this image accepts the Android SDK licence (sdkmanager --licenses).
FROM ubuntu:24.04

ARG GODOT_VERSION=4.7.1
ARG CMDLINE_TOOLS=11076708

ENV ANDROID_HOME=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    XDG_DATA_HOME=/opt/xdg-data
ENV PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openjdk-17-jdk-headless unzip wget ca-certificates libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p $ANDROID_HOME/cmdline-tools \
 && wget -q https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS}_latest.zip -O /tmp/ct.zip \
 && unzip -q /tmp/ct.zip -d $ANDROID_HOME/cmdline-tools \
 && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
 && rm /tmp/ct.zip \
 && yes | sdkmanager --licenses > /dev/null \
 && sdkmanager "platform-tools" "build-tools;35.0.1" "platforms;android-35" > /dev/null

# Godot looks for templates in $XDG_DATA_HOME/godot/export_templates/<version>.stable/.
# Only the prebuilt Android templates are kept (no Gradle build, PLAN.md 0.9).
RUN T=$XDG_DATA_HOME/godot/export_templates/${GODOT_VERSION}.stable \
 && mkdir -p $T \
 && wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz -O /tmp/t.tpz \
 && unzip -q -j /tmp/t.tpz 'templates/android_debug.apk' 'templates/android_release.apk' 'templates/version.txt' -d $T \
 && rm /tmp/t.tpz \
 && chmod -R a+rwX $XDG_DATA_HOME

WORKDIR /work
