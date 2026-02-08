const rooms = globalThis.__rooms || (globalThis.__rooms = new Map());

export default function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(200).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { room_id, from, type, data } = req.body || {};
  if (!room_id || !from || !type) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  const room = rooms.get(room_id);
  if (!room) return res.status(404).json({ error: "Room not found" });

  // Push signal to the OTHER peer's queue
  const target = from === "host" ? "client" : "host";
  room.signals[target].push({ type, data, timestamp: Date.now() });

  res.json({ success: true });
}
