#!/bin/bash
# Launch Rocky on Desk with WSL Electron dependencies
export LD_LIBRARY_PATH="$HOME/electron-libs/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
cd "$(dirname "$0")"
npm start -- --disable-gpu --no-sandbox
