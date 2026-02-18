#!/bin/bash
# Deploy Mining Defense signaling server to Vercel
# Usage: ./deploy-vercel.sh [--local]
#
# Prerequisites:
#   npm i -g vercel (one-time setup)

set -e

if [ "$1" = "--local" ]; then
    echo "Starting local dev server on http://localhost:3000..."
    cd vercel-signaling
    vercel dev
else
    echo "Deploying signaling server to Vercel..."
    cd vercel-signaling
    npx vercel --prod
fi
