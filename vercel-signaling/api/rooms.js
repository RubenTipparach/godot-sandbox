import { Redis } from "@upstash/redis";

const redis = Redis.fromEnv();
const ROOM_TTL = 300; // 5 minutes

function cors(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function roomKey(id) {
  return `room:${id}`;
}

function signalKey(roomId, role) {
  return `signals:${roomId}:${role}`;
}

export default async function handler(req, res) {
  cors(res);
  if (req.method === "OPTIONS") return res.status(200).end();

  const action = req.query.action;

  switch (action) {
    case "create": {
      if (req.method !== "POST") return res.status(405).json({ error: "POST required" });
      const roomId = Math.random().toString(36).substring(2, 8).toUpperCase();
      await redis.set(roomKey(roomId), JSON.stringify({ next_client_id: 2, client_ids: [] }), { ex: ROOM_TTL });
      return res.json({ room_id: roomId });
    }

    case "join": {
      if (req.method !== "POST") return res.status(405).json({ error: "POST required" });
      const { room_id } = req.body || {};
      if (!room_id) return res.status(400).json({ error: "Missing room_id" });
      const room = await redis.get(roomKey(room_id));
      if (!room) return res.status(404).json({ error: "Room not found" });
      const roomData = typeof room === "string" ? JSON.parse(room) : room;

      const clientId = roomData.next_client_id || 2;
      roomData.client_ids = roomData.client_ids || [];
      roomData.client_ids.push(clientId);
      roomData.next_client_id = clientId + 1;

      await redis.set(roomKey(room_id), JSON.stringify(roomData), { ex: ROOM_TTL });
      return res.json({ success: true, client_id: clientId });
    }

    case "signal": {
      if (req.method !== "POST") return res.status(405).json({ error: "POST required" });
      const { room_id: sigRoomId, from, type, data, to } = req.body || {};
      if (!sigRoomId || !from || !type) {
        return res.status(400).json({ error: "Missing required fields" });
      }
      const room = await redis.get(roomKey(sigRoomId));
      if (!room) return res.status(404).json({ error: "Room not found" });

      // Host sends to a specific client via "to" field; clients send to "host"
      const target = from === "host" ? (to || "client") : "host";

      await redis.rpush(signalKey(sigRoomId, target), JSON.stringify({ type, data, from }));
      await redis.expire(signalKey(sigRoomId, target), ROOM_TTL);
      return res.json({ success: true });
    }

    case "poll": {
      const { room_id: pollRoomId, as: role } = req.query;
      if (!pollRoomId || !role) {
        return res.status(400).json({ error: "Missing room_id or as parameter" });
      }
      const room = await redis.get(roomKey(pollRoomId));
      if (!room) return res.status(404).json({ error: "Room not found" });
      const roomData = typeof room === "string" ? JSON.parse(room) : room;

      // Drain all signals from the list atomically
      const key = signalKey(pollRoomId, role);
      const len = await redis.llen(key);
      let messages = [];
      if (len > 0) {
        messages = await redis.lrange(key, 0, -1);
        await redis.del(key);
        messages = messages.map((m) => (typeof m === "string" ? JSON.parse(m) : m));
      }
      return res.json({
        messages,
        client_ids: roomData.client_ids || [],
        player_count: (roomData.client_ids || []).length + 1,
      });
    }

    default:
      return res.status(400).json({ error: "Unknown action" });
  }
}
