import { useCallback, useEffect, useMemo, useState } from "react";
import "./community-ports.scss";

/** A separate discovery index: it does not impersonate Hydra's Steam catalogue. */
type Port = {
  title: string;
  projectUrl: string;
  description: string;
  platforms: string[];
  source: string;
};
type Feed = { name: string; url: string };
type Saved = { feeds: Feed[]; custom: Port[] };
const KEY = "hydra-community-ports-v1";
const DEFAULT_FEED: Feed = {
  name: "Hydra Community PC Ports",
  url: "https://raw.githubusercontent.com/imnotsharingmyname/ProtonLess-Steam-Launcher/hydra-macos-ci-experiment/hydra-macos-ci/community-ports-index.json",
};

const featured: Port[] = [
  {
    title: "Ship of Harkinian",
    projectUrl: "https://github.com/HarbourMasters/Shipwright",
    description: "Community reverse-engineered desktop port project for Ocarina of Time. See its repository for requirements and supported platforms.",
    platforms: ["Desktop"],
    source: "Featured projects",
  },
  {
    title: "Super Mario 64 — sm64ex",
    projectUrl: "https://github.com/sm64pc/sm64ex",
    description: "Community-maintained native desktop port project. Requires your own legally obtained game assets.",
    platforms: ["Desktop"],
    source: "Featured projects",
  },
  {
    title: "OpenGOAL",
    projectUrl: "https://github.com/open-goal/jak-project",
    description: "Open-source Jak and Daxter reverse-engineering and desktop runtime project.",
    platforms: ["Desktop"],
    source: "Featured projects",
  },
];

function validHttps(input: unknown): input is string {
  if (typeof input !== "string" || input.length > 2048) return false;
  try {
    const u = new URL(input);
    return u.protocol === "https:" && Boolean(u.hostname);
  } catch {
    return false;
  }
}

function parsePort(input: unknown, source: string): Port | null {
  if (!input || typeof input !== "object") return null;
  const p = input as Record<string, unknown>;
  if (typeof p.title !== "string" || !p.title.trim() || p.title.length > 160 ||
      !validHttps(p.projectUrl)) return null;
  return {
    title: p.title.trim(),
    projectUrl: p.projectUrl,
    description: typeof p.description === "string" ? p.description.slice(0, 800) : "",
    platforms: Array.isArray(p.platforms)
      ? p.platforms.filter((x): x is string => typeof x === "string" && x.length < 40).slice(0, 8)
      : [],
    source,
  };
}

function loadSaved(): Saved {
  try {
    const existing = localStorage.getItem(KEY);
    if (!existing) return { feeds: [DEFAULT_FEED], custom: [] };
    const raw = JSON.parse(existing) as Record<string, unknown>;
    const feeds = Array.isArray(raw.feeds)
      ? raw.feeds.filter((f): f is Feed => !!f && typeof f === "object" &&
          typeof f.name === "string" && f.name.length < 100 && validHttps(f.url)).slice(0, 20)
      : [];
    const custom = Array.isArray(raw.custom)
      ? raw.custom.map((p) => parsePort(p, "My entries")).filter((p): p is Port => !!p).slice(0, 300)
      : [];
    return { feeds, custom };
  } catch {
    return { feeds: [], custom: [] };
  }
}

async function fetchFeed(feed: Feed): Promise<Port[]> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(feed.url, { signal: controller.signal, cache: "no-store" });
    if (!response.ok) throw new Error("HTTP " + response.status);
    const size = response.headers.get("content-length");
    if (size && Number(size) > 1024 * 1024) throw new Error("Index is too large");
    const text = await response.text();
    if (text.length > 1024 * 1024) throw new Error("Index is too large");
    const parsed: unknown = JSON.parse(text);
    const entries = Array.isArray(parsed) ? parsed :
      parsed && typeof parsed === "object" && "entries" in parsed
        ? (parsed as { entries: unknown }).entries : null;
    if (!Array.isArray(entries)) throw new Error("Expected a JSON array or { entries: [...] }");
    return entries.slice(0, 500)
      .map((item) => parsePort(item, feed.name))
      .filter((item): item is Port => item !== null);
  } finally {
    clearTimeout(timer);
  }
}

export default function CommunityPorts() {
  const [saved, setSaved] = useState<Saved>(loadSaved);
  const [feedEntries, setFeedEntries] = useState<Port[]>([]);
  const [query, setQuery] = useState("");
  const [platform, setPlatform] = useState("All");
  const [feedName, setFeedName] = useState("");
  const [feedUrl, setFeedUrl] = useState("");
  const [newTitle, setNewTitle] = useState("");
  const [newUrl, setNewUrl] = useState("");
  const [newDescription, setNewDescription] = useState("");
  const [newPlatforms, setNewPlatforms] = useState("Desktop");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    localStorage.setItem(KEY, JSON.stringify(saved));
  }, [saved]);

  const refresh = useCallback(async () => {
    if (saved.feeds.length === 0) {
      setFeedEntries([]);
      return;
    }
    setLoading(true);
    const results = await Promise.allSettled(saved.feeds.map(fetchFeed));
    const loaded: Port[] = [];
    const errors: string[] = [];
    results.forEach((result, i) => {
      if (result.status === "fulfilled") loaded.push(...result.value);
      else errors.push(saved.feeds[i].name + ": " + String(result.reason));
    });
    setFeedEntries(loaded);
    setMessage(errors.length
      ? "Some indexes failed: " + errors.join("; ") + ". HTTPS indexes must allow browser CORS."
      : "Refreshed " + loaded.length + " community entries.");
    setLoading(false);
  }, [saved.feeds]);

  useEffect(() => { void refresh(); }, [refresh]);

  const ports = useMemo(() => {
    const unique = new Map<string, Port>();
    [...saved.custom, ...feedEntries, ...featured].forEach((p) => {
      if (!unique.has(p.projectUrl)) unique.set(p.projectUrl, p);
    });
    return Array.from(unique.values());
  }, [saved.custom, feedEntries]);

  const platforms = useMemo(() => ["All", ...Array.from(
    new Set(ports.flatMap((p) => p.platforms))
  ).sort()], [ports]);

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return ports.filter((p) =>
      (platform === "All" || p.platforms.includes(platform)) &&
      (!q || [p.title, p.description, p.source, ...p.platforms].join(" ").toLowerCase().includes(q))
    ).sort((a, b) => a.title.localeCompare(b.title));
  }, [ports, platform, query]);

  const addFeed = (event: React.FormEvent) => {
    event.preventDefault();
    if (!validHttps(feedUrl)) { setMessage("Index URL must be a valid HTTPS address."); return; }
    if (saved.feeds.some((f) => f.url === feedUrl)) { setMessage("Index already added."); return; }
    if (saved.feeds.length >= 20) { setMessage("Maximum 20 indexes."); return; }
    setSaved((prev) => ({
      ...prev,
      feeds: [...prev.feeds, { name: feedName.trim().slice(0, 99) || new URL(feedUrl).hostname, url: feedUrl }],
    }));
    setFeedName(""); setFeedUrl(""); setMessage("Index added; fetching its entries.");
  };

  const addEntry = (event: React.FormEvent) => {
    event.preventDefault();
    const p = parsePort({
      title: newTitle,
      projectUrl: newUrl,
      description: newDescription,
      platforms: newPlatforms.split(",").map((s) => s.trim()).filter(Boolean),
    }, "My entries");
    if (!p) { setMessage("Enter a title and a valid HTTPS project link."); return; }
    if (saved.custom.length >= 300) { setMessage("Maximum 300 custom entries."); return; }
    setSaved((prev) => ({ ...prev, custom: [p, ...prev.custom.filter((x) => x.projectUrl !== p.projectUrl)] }));
    setNewTitle(""); setNewUrl(""); setNewDescription(""); setMessage("Project added.");
  };

  return (
    <main className="community-ports">
      <div className="community-ports__intro">
        <p className="community-ports__eyebrow">COMMUNITY DISCOVERY</p>
        <h1>Unofficial PC Ports</h1>
        <p>Discover community desktop port projects without leaving Hydra. This is a separate index, not Hydra's official game catalogue or download-source system.</p>
      </div>
      <div className="community-ports__search">
        <input aria-label="Search ports" placeholder="Search ports, projects, platforms…" value={query} onChange={(e) => setQuery(e.target.value)} />
        <select aria-label="Platform" value={platform} onChange={(e) => setPlatform(e.target.value)}>
          {platforms.map((p) => <option key={p} value={p}>{p}</option>)}
        </select>
        <span>{visible.length} projects</span>
      </div>
      <div className="community-ports__grid">
        {visible.map((p) => (
          <article className="community-ports__card" key={p.projectUrl}>
            <div className="community-ports__card-top"><strong>{p.title}</strong><small>{p.source}</small></div>
            <p>{p.description || "Visit the project's homepage for details."}</p>
            <div className="community-ports__tags">
              {p.platforms.map((tag) => <span key={tag}>{tag}</span>)}
            </div>
            <div className="community-ports__actions">
              <button type="button" onClick={() => void window.electron.openExternal(p.projectUrl)}>Project website ↗</button>
              {p.source === "My entries" && <button type="button" className="community-ports__quiet"
                onClick={() => setSaved((prev) => ({ ...prev, custom: prev.custom.filter((x) => x.projectUrl !== p.projectUrl) }))}>Remove</button>}
            </div>
          </article>
        ))}
        {visible.length === 0 && <p>No matching projects. Try a different search or add an index.</p>}
      </div>
      <div className="community-ports__management">
        <section>
          <h2>Community JSON indexes</h2>
          <p>Add an HTTPS JSON index, for example a raw GitHub-hosted file. Entries are fetched in Hydra and linked to their project websites.</p>
          <form onSubmit={addFeed}>
            <input aria-label="Index name" placeholder="Index name" value={feedName} onChange={(e) => setFeedName(e.target.value)} />
            <input aria-label="Index HTTPS URL" placeholder="https://raw.githubusercontent.com/…/ports.json" value={feedUrl} onChange={(e) => setFeedUrl(e.target.value)} />
            <button type="submit">Add index</button>
          </form>
          {saved.feeds.map((f) => (
            <div className="community-ports__feed" key={f.url}>
              <span title={f.url}>{f.name}</span>
              <button type="button" onClick={() => setSaved((prev) => ({ ...prev, feeds: prev.feeds.filter((x) => x.url !== f.url) }))}>Remove</button>
            </div>
          ))}
          <button type="button" disabled={loading} onClick={() => void refresh()}>{loading ? "Refreshing…" : "Refresh indexes"}</button>
        </section>
        <section>
          <h2>Add a project</h2>
          <p>Save an unofficial port or source project locally. Only project links are opened; no game files are downloaded automatically.</p>
          <form onSubmit={addEntry}>
            <input aria-label="Project title" placeholder="Project name" value={newTitle} onChange={(e) => setNewTitle(e.target.value)} />
            <input aria-label="Project HTTPS URL" placeholder="https://github.com/…" value={newUrl} onChange={(e) => setNewUrl(e.target.value)} />
            <input aria-label="Description" placeholder="Short description" value={newDescription} onChange={(e) => setNewDescription(e.target.value)} />
            <input aria-label="Platforms" placeholder="Platforms (comma-separated)" value={newPlatforms} onChange={(e) => setNewPlatforms(e.target.value)} />
            <button type="submit">Save project</button>
          </form>
        </section>
      </div>
      {message && <p className="community-ports__message" role="status">{message}</p>}
      <p className="community-ports__disclaimer">Projects are community-maintained and may require original game files. Check their licences and download software only from sources you trust.</p>
    </main>
  );
}
