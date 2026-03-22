import { spawn } from "child_process";
import { readFileSync } from "fs";
import { join } from "path";

const PORT = 6969;
const TMUX_SESSION = "research-group";
const POLL_IDLE_MS = 1000;
const POLL_ACTIVE_MS = 150;

const AGENTS = [
  { role: "senior-researcher", pane: "senior-researcher.0", kit: "research-kit", color: "#60a5fa" },
  { role: "engineer", pane: "engineer.0", kit: "tdd-kit", color: "#34d399" },
  { role: "theorist", pane: "theorist.0", kit: "mathematics-kit", color: "#c084fc" },
  { role: "strategist", pane: "strategist.0", kit: "coordinator", color: "#f97316" },
  { role: "surveyor", pane: "surveyor.0", kit: "research-kit", color: "#38bdf8" },
  { role: "scribe", pane: "scribe.0", kit: "paper", color: "#fbbf24" },
  { role: "pi", pane: "pi.0", kit: "coordinator", color: "#f43f5e" },
  { role: "htop", pane: "htop.0", kit: "system", color: "#a6e3a1" },
];

function capturePaneRaw(pane: string, lines = 200): Promise<string> {
  return new Promise((resolve) => {
    const proc = spawn("tmux", [
      "capture-pane", "-t", `${TMUX_SESSION}:${pane}`, "-p", "-e", `-S`, `-${lines}`
    ]);
    let out = "";
    proc.stdout.on("data", (d: Buffer) => (out += d.toString()));
    proc.stderr.on("data", () => {});
    proc.on("close", () => resolve(out));
    proc.on("error", () => resolve(""));
  });
}

function extractTokens(text: string): string {
  const m = text.match(/([0-9,]+)\s*tokens/);
  return m ? m[1] : "0";
}

// Track which role the client is focused on for faster polling
const wsClients = new Set<any>();
let activeRole: string | null = null;
let lastActiveTime = 0;

async function pollPanes() {
  const now = Date.now();
  const isActive = activeRole && (now - lastActiveTime < 5000);

  const results = await Promise.all(
    AGENTS.map(async (a) => {
      const text = await capturePaneRaw(a.pane, isActive && a.role === activeRole ? 500 : 80);
      const tokens = extractTokens(text);
      return { role: a.role, pane: a.pane, kit: a.kit, color: a.color, tokens, text };
    })
  );

  const msg = JSON.stringify({ type: "update", agents: results });
  for (const ws of wsClients) {
    try { ws.send(msg); } catch { wsClients.delete(ws); }
  }

  // Poll faster when user is actively typing
  const nextPoll = isActive ? POLL_ACTIVE_MS : POLL_IDLE_MS;
  setTimeout(pollPanes, nextPoll);
}

pollPanes();

// Serve
const html = readFileSync(join(import.meta.dir, "index.html"), "utf-8");

const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);
    if (url.pathname === "/") return new Response(html, { headers: { "Content-Type": "text/html" } });
    if (url.pathname === "/ws") {
      if (server.upgrade(req)) return undefined as any;
      return new Response("WebSocket upgrade failed", { status: 500 });
    }
    return new Response("Not Found", { status: 404 });
  },
  websocket: {
    open(ws) { wsClients.add(ws); },
    close(ws) { wsClients.delete(ws); },
    message(ws, msg) {
      try {
        const data = JSON.parse(msg as string);

        if (data.type === "focus") {
          activeRole = data.role;
          lastActiveTime = Date.now();
        }

        if (data.type === "unfocus") {
          if (activeRole === data.role) activeRole = null;
        }

        if (data.type === "key") {
          // Send a single key/keystroke to the tmux pane
          const agent = AGENTS.find(a => a.role === data.role);
          if (!agent) return;
          lastActiveTime = Date.now();
          activeRole = data.role;

          // tmux send-keys with the key name (e.g., "Enter", "Escape", "C-c")
          const proc = spawn("tmux", [
            "send-keys", "-t", `${TMUX_SESSION}:${agent.pane}`, data.key
          ]);
          proc.on("error", () => {});
        }

        if (data.type === "literal") {
          // Send literal text (single character usually)
          const agent = AGENTS.find(a => a.role === data.role);
          if (!agent) return;
          lastActiveTime = Date.now();
          activeRole = data.role;

          const proc = spawn("tmux", [
            "send-keys", "-t", `${TMUX_SESSION}:${agent.pane}`, "-l", data.text
          ]);
          proc.on("error", () => {});
        }
      } catch {}
    },
  },
});

console.log(`Kenoma Dashboard running at http://localhost:${PORT}`);
