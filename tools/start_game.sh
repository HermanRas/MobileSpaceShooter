#!/usr/bin/env bash
GODOT=~/Downloads/Godot_v4.7.1/Godot_v4.7.1-stable_linux.x86_64
# Refresh the class cache first, or a newly added `class_name` reads as "not declared".
$GODOT --headless --path game --import >/dev/null 2>&1 || true
$GODOT --path game
