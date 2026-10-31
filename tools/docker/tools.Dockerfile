# The offline tools image: Python (Pillow, numpy) for the art pipeline, vorbis-tools for the
# audio pipeline (tools/make_audio.py: oggdec in, oggenc out), and a virtual X
# display so Godot can render screenshots without opening a window on the host.
# Godot itself is NOT in the image; tools/run.sh mounts the pinned binary read-only.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-pil python3-numpy vorbis-tools \
      xvfb xauth \
      libgl1 libgl1-mesa-dri libglx-mesa0 libegl1 \
      libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxext6 libxrender1 \
      libxkbcommon0 libxkbcommon-x11-0 libfontconfig1 libdbus-1-3 \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work
