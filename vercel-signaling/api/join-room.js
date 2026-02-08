const rooms = globalThis.__rooms || (globalThis.__rooms = new Map());

export default function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { room_id } = req.body || {};
  if (!room_id) return res.status(400).json({ error: "Missing room_id" });

  const room = rooms.get(room_id);
  if (!room) return res.status(404).json({ error: "Room not found" });

  room.joined = true;
  res.json({ success: true });
}
