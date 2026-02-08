const rooms = globalThis.__rooms || (globalThis.__rooms = new Map());

function cors(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

export default function handler(req, res) {
  cors(res);
  if (req.method === "OPTIONS") return res.status(200).end();

  const action = req.query.action;

  // Cleanup expired rooms (older than 5 minutes)
  const now = Date.now();
  for (const [id, room] of rooms) {
    if (now - room.created > 300000) rooms.delete(id);
  }

  switch (action) {
    case "create": {
      if (req.method !== "POST") return res.status(405).json({ error: "POST required" });
      const roomId = Math.random().toString(36).substring(2, 8).toUpperCase();
      rooms.set(roomId, {
        created: now,
        joined: false,
        signals: { host: [], client: [] },
      });
      return res.json({ room_id: roomId });
    }

    case "join": {
      if (req.method !== "POST") return res.status(405).json({ error: "POST required" });
      const { room_id } = req.body || {};
      if (!room_id) return res.status(400).json({ error: "Missing room_id" });
      const room = rooms.get(room_id);
      if (!room) return res.status(404).json({ error: "Room not found" });
      room.joined = true;
      return res.json({ success: true });
    }

    case "signal": {
      if (req.method !== "POST") return res.status(405).json({ error: "POST required" });
      const { room_id: sigRoomId, from, type, data } = req.body || {};
      if (!sigRoomId || !from || !type) {
        return res.status(400).json({ error: "Missing required fields" });
      }
      const sigRoom = rooms.get(sigRoomId);
      if (!sigRoom) return res.status(404).json({ error: "Room not found" });
      const target = from === "host" ? "client" : "host";
      sigRoom.signals[target].push({ type, data, timestamp: now });
      return res.json({ success: true });
    }

    case "poll": {
      const { room_id: pollRoomId, as: role } = req.query;
      if (!pollRoomId || !role) {
        return res.status(400).json({ error: "Missing room_id or as parameter" });
      }
      const pollRoom = rooms.get(pollRoomId);
      if (!pollRoom) return res.status(404).json({ error: "Room not found" });
      const messages = pollRoom.signals[role] || [];
      pollRoom.signals[role] = [];
      return res.json({ messages, joined: pollRoom.joined });
    }

    default:
      return res.status(400).json({ error: "Unknown action", rooms_count: rooms.size });
  }
}
