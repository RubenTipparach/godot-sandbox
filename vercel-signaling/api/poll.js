const rooms = globalThis.__rooms || (globalThis.__rooms = new Map());

export default function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(200).end();
  if (req.method !== "GET") return res.status(405).json({ error: "Method not allowed" });

  const { room_id, as: role } = req.query || {};
  if (!room_id || !role) {
    return res.status(400).json({ error: "Missing room_id or as parameter" });
  }

  const room = rooms.get(room_id);
  if (!room) return res.status(404).json({ error: "Room not found" });

  // Drain all pending signals for this peer
  const messages = room.signals[role] || [];
  room.signals[role] = [];

  res.json({ messages, joined: room.joined });
}
