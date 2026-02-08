# Multiplayer Setup Guide

2-player co-op multiplayer using WebRTC peer-to-peer with a Vercel signaling server.

## How It Works

- **Vercel serverless functions** (`/api/*`) handle the ~5-second WebRTC signaling handshake (exchanging SDP offers and ICE candidates between peers)
- **Game files** (`/game/*`) serve the Godot WASM build with required COOP/COEP headers
- **After connecting**, all gameplay traffic goes directly peer-to-peer over WebRTC — Vercel is no longer involved

## Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- [Vercel CLI](https://vercel.com/docs/cli): `npm i -g vercel`
- Godot 4.4+ with Web export templates installed
- [Upstash Redis](https://upstash.com/) account (free tier works fine)

## Local Testing

### 1. Export the game

In Godot Editor: **Project > Export > Web > Export Project**

This exports to `godot-sandbox/game/` based on the existing preset.

### 2. Copy game build into the signaling folder

```bash
# From repo root
cp -r godot-sandbox/game vercel-signaling/game
```

Or use the helper script:

```bash
./deploy-vercel.sh --local
```

### 3. Set up Upstash Redis

1. Go to [console.upstash.com](https://console.upstash.com/) and create a free Redis database
2. Copy the **REST URL** and **REST Token** from the database details page
3. Create a `.env` file in `vercel-signaling/`:

```bash
UPSTASH_REDIS_REST_URL=https://your-db.upstash.io
UPSTASH_REDIS_REST_TOKEN=your-token-here
```

### 4. Install dependencies

```bash
cd vercel-signaling
npm install
```

### 5. Start local dev server

```bash
cd vercel-signaling
vercel dev
```

This starts everything on `http://localhost:3000` — both the signaling API and game files.

### 6. Test multiplayer

1. Open **two browser tabs** to `http://localhost:3000`
2. **Tab 1:** Click **Host Co-op** → you'll see a 6-character room code
3. **Tab 2:** Click **Join Co-op** → type in the room code → click **Connect**
4. **Tab 1:** Click **Start Game** once the status shows "Connected"

Both players should now see the game with two colored triangles (green = host, blue = client).

## Deploy to Vercel

### 1. Export the game

Same as above — Godot Editor: **Project > Export > Web > Export Project**

### 2. Deploy

```bash
./deploy-vercel.sh
```

Or manually:

```bash
cp -r godot-sandbox/game vercel-signaling/game
cd vercel-signaling
npx vercel --prod
```

The first time, Vercel will prompt you to link/create a project. After that, you'll get a URL like `https://mining-defense-xyz.vercel.app`.

### 3. Play with a friend

Share the deployed URL. One player clicks **Host Co-op**, the other clicks **Join Co-op** and enters the room code.

## CI/CD: Auto-Deploy via GitHub Actions

Every push to `main` automatically exports the game and deploys to Vercel.

### One-time setup

1. **Create a Vercel project** (if you haven't already):
   ```bash
   cd vercel-signaling
   npx vercel
   ```
   Follow the prompts to link/create a project. This generates a `.vercel/project.json` with your org and project IDs.

2. **Get your Vercel token:**
   Go to https://vercel.com/account/tokens → create a new token.

3. **Add these GitHub repo secrets** (Settings > Secrets and variables > Actions):

   | Secret | Where to find it |
   |--------|-----------------|
   | `VERCEL_TOKEN` | The token from step 2 |
   | `VERCEL_ORG_ID` | From `vercel-signaling/.vercel/project.json` → `orgId` |
   | `VERCEL_PROJECT_ID` | From `vercel-signaling/.vercel/project.json` → `projectId` |
   | `UPSTASH_REDIS_REST_URL` | From Upstash console → your database → REST URL |
   | `UPSTASH_REDIS_REST_TOKEN` | From Upstash console → your database → REST Token |

4. **Add Upstash env vars to your Vercel project** (also needed for production):
   ```bash
   cd vercel-signaling
   vercel env add UPSTASH_REDIS_REST_URL production
   vercel env add UPSTASH_REDIS_REST_TOKEN production
   ```
   Or add them in the Vercel dashboard: Project Settings > Environment Variables.

5. Push to `main` — the workflow will export the game, bundle it with the signaling API, and deploy to Vercel automatically.

The workflow is at `.github/workflows/deploy-vercel.yml`. It also supports manual dispatch from the Actions tab.

## Architecture

```
Vercel (static + serverless)
  /game/*          → Godot web export (WASM)
  /api/create-room → create 6-char room code
  /api/join-room   → mark room as joining
  /api/signal      → exchange SDP/ICE data
  /api/poll        → poll for pending signals

Player A (Host)                    Player B (Client)
  runs all game logic  ←—WebRTC P2P—→  sends input, receives state
  spawns enemies                        renders puppet enemies
  validates builds                      sends build requests
  owns shared resources                 receives resource updates
```

## Networking Model

| Data | Direction | Channel | Frequency |
|------|-----------|---------|-----------|
| Player input (move, angle) | Client → Host | Unreliable | 60Hz |
| Player state (pos, HP, resources) | Host → Client | Unreliable | 20Hz |
| Enemy positions + HP | Host → Client | Unreliable | 20Hz |
| Enemy spawn/death events | Host → Client | Reliable | On event |
| Building create/destroy | Bidirectional | Reliable | On event |
| Upgrade trigger/choice | Bidirectional | Reliable | On event |
| Wave alerts | Host → Client | Reliable | On event |
| Game over | Host → Client | Reliable | Once |
| Prestige/Research | Local only | N/A | N/A |

## Notes

- **Signaling uses Upstash Redis.** Room codes and signaling messages are stored in Upstash Redis with a 5-minute TTL. This works reliably across Vercel serverless invocations (unlike in-memory storage which doesn't survive between function instances).
- **Solo mode is unaffected.** All multiplayer code checks `NetworkManager.is_multiplayer_active()` before running. Single-player works exactly as before.
- **Prestige/research stays local.** Each browser saves independently to `user://`. Co-op shares resources and buildings during the game, but meta-progression is per-player.
- **`vercel-signaling/game/` is gitignored.** Don't commit the WASM build — re-export from Godot each time.
