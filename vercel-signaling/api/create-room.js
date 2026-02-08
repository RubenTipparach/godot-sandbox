const rooms = globalThis.__rooms || (globalThis.__rooms = new Map());

export default function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  // Cleanup expired rooms (older than 5 minutes)
  const now = Date.now();
  for (const [id, room] of rooms) {
    if (now - room.created > 300000) rooms.delete(id);
  }

  const roomId = Math.random().toString(36).substring(2, 8).toUpperCase();
  rooms.set(roomId, {
    created: now,
    joined: false,
    signals: { host: [], client: [] },
  });

  res.json({ room_id: roomId });
}
