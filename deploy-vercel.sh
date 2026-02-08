#!/bin/bash
# Deploy Mining Defense to Vercel (game + signaling server)
# Usage: ./deploy-vercel.sh [--local]
#
# Prerequisites:
#   1. Export the game from Godot Editor: Project > Export > Web
#   2. npm i -g vercel (one-time setup)

set -e

# Copy game build into vercel-signaling
if [ ! -d "godot-sandbox/game" ]; then
    echo "ERROR: No game build found at godot-sandbox/game/"
    echo "Export the game from Godot Editor first: Project > Export > Web"
    exit 1
fi

echo "Copying game build to vercel-signaling/game/..."
rm -rf vercel-signaling/game
cp -r godot-sandbox/game vercel-signaling/game

if [ "$1" = "--local" ]; then
    echo "Starting local dev server on http://localhost:3000..."
    cd vercel-signaling
    vercel dev
else
    echo "Deploying to Vercel..."
    cd vercel-signaling
    npx vercel --prod
fi
