#!/bin/bash
# Shared helpers for theme scripts

toml_val() {
    local key="$1" toml="$2"
    grep "^$key " "$toml" 2>/dev/null | sed 's/.*= *"//;s/".*//' | tr -d '\n'
}
