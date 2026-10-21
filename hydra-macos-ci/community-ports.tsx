import { useCallback, useEffect, useMemo, useState } from "react";
import "./community-ports.scss";

/** A separate discovery index: it does not impersonate Hydra's Steam catalogue. */
type Port = {
  title: string;
  projectUrl: string;
  description: string;
  platforms: string[];
  source: string;
  origin?: string;
  buildType?: string;
};
type ReleaseInfo = {
  name: string;
  url: string;
  publishedAt?: string;
  assets: { name: string; url: string; size?: number }[];
};

type Feed = { name: string; url: string };
type Saved = { feeds: Feed[]; custom: Port[] };
const KEY = "hydra-community-ports-v1";
const DEFAULT_FEED: Feed = {
  name: "Console Ports Index",
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
    origin: typeof p.origin === "string" ? p.origin.slice(0, 60) : undefined,
    buildType: typeof p.buildType === "string" ? p.buildType.slice(0, 80) : undefined,
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

/** RSS reader: only indexes public article titles/URLs, never downloads. */
function parseConsoleRss(xml: string): Port[] {
  const parsed = new DOMParser().parseFromString(xml, "application/xml");
  if (parsed.querySelector("parsererror")) throw new Error("Invalid source RSS XML");
  return Array.from(parsed.querySelectorAll("item")).slice(0, 100).flatMap((item) => {
    const title = item.querySelector("title")?.textContent?.trim() || "";
    const link = item.querySelector("link")?.textContent?.trim() || "";
    const description = item.querySelector("description")?.textContent || "";
    const searchable = title + " " + description.slice(0, 500);
    // This source contains ordinary PC games too: show ONLY the port-specific
    // postings, not the site's entire game catalogue.
    if (!/\b(?:bloodborne|console[\s-]*to[\s-]*pc|pc port|ps[345] port|xbox port|playstation port|shadps4)\b/i.test(searchable)) {
      return [];
    }
    if (!validHttps(link) || new URL(link).hostname !== "fitgirl-repacks.site") return [];
    const p = parsePort({
      title,
      projectUrl: link,
      description: "Full-build listing on the source site. Check the original article for details and legitimacy.",
      platforms: ["Windows", "Port listing"],
      origin: "Console / other platforms",
      buildType: "Complete-build listing",
    }, "FitGirl RSS · listing metadata");
    return p ? [p] : [];
  });
}

/** GitHub project release information is independent of Hydra's Steam IDs. */
function githubProject(url: string): string | null {
  try {
    const parsed = new URL(url);
    if (parsed.hostname !== "github.com") return null;
    const parts = parsed.pathname.split("/").filter(Boolean);
    if (parts.length !== 2 || !parts.every((p) => /^[\w.-]+$/.test(p))) return null;
    return parts.join("/");
  } catch {
    return null;
  }
}

async function getLatestRelease(repo: string): Promise<ReleaseInfo | null> {
  const response = await fetch("https://api.github.com/repos/" + repo + "/releases/latest", {
    headers: { Accept: "application/vnd.github+json" },
  });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error("GitHub HTTP " + response.status);
  const data = await response.json() as {
    name?: string; tag_name?: string; html_url?: string; published_at?: string;
    assets?: { name: string; browser_download_url: string; size?: number }[];
  };
  if (!validHttps(data.html_url) || !data.html_url.startsWith("https://github.com/")) return null;
  const assets = (data.assets ?? [])
    .filter((a) => validHttps(a.browser_download_url) &&
      a.browser_download_url.startsWith("https://github.com/") &&
      /\.(zip|dmg|pkg|exe|appimage|tar\.gz|tar\.xz|7z|msi)$/i.test(a.name))
    .slice(0, 12)
    .map((a) => ({ name: a.name, url: a.browser_download_url, size: a.size }));
  return {
    name: data.name || data.tag_name || "Latest release",
    url: data.html_url,
    publishedAt: data.published_at,
    assets,
  };
}

export default function CommunityPorts() {
  const [saved, setSaved] = useState<Saved>(loadSaved);
  const [feedEntries, setFeedEntries] = useState<Port[]>([]);
  const [githubReleases, setGithubReleases] = useState<Record<string, ReleaseInfo>>({});
  const [rssEntries, setRssEntries] = useState<Port[]>([]);
  const [rssStatus, setRssStatus] = useState("Not checked");
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
    setLoading(true);
    const rssApi = window.electron as typeof window.electron & { fetchConsolePortsRss: () => Promise<string> };
    const results = await Promise.allSettled([
      ...saved.feeds.map(fetchFeed),
      rssApi.fetchConsolePortsRss().then(parseConsoleRss),
    ]);
    const loaded: Port[] = [];
    const errors: string[] = [];
    results.slice(0, -1).forEach((result, i) => {
      if (result.status === "fulfilled") loaded.push(...result.value);
      else errors.push(saved.feeds[i].name + ": " + String(result.reason));
    });
    const rss = results[results.length - 1];
    if (rss.status === "fulfilled") {
      setRssEntries(rss.value);
      setRssStatus("Checked · " + rss.value.length + " console port listings found");
    } else {
      setRssEntries([]);
      setRssStatus("Temporarily unavailable · " + String(rss.reason));
    }
    setFeedEntries(loaded);
    setMessage(errors.length
      ? "Some community indexes failed: " + errors.join("; ")
      : "Refreshed " + loaded.length + " community index entries.");
    setLoading(false);
  }, [saved.feeds]);

  // Automatically refresh while Hydra is running. A closed app cannot refresh.
  useEffect(() => {
    void refresh();
    const timer = setInterval(() => { void refresh(); }, 6 * 60 * 60 * 1000);
    return () => clearInterval(timer);
  }, [refresh]);

  const ports = useMemo(() => {
    const unique = new Map<string, Port>();
    [...saved.custom, ...rssEntries, ...feedEntries, ...featured].forEach((p) => {
      if (!unique.has(p.projectUrl)) unique.set(p.projectUrl, p);
    });
    return Array.from(unique.values());
  }, [saved.custom, feedEntries, rssEntries]);

  useEffect(() => {
    let cancelled = false;
    const repos = Array.from(new Set(ports.map((p) => githubProject(p.projectUrl))
      .filter((repo): repo is string => repo !== null))).slice(0, 30);
    // API limit applies to unauthenticated GitHub users. Refresh on page opening
    // and whenever the configured catalogue changes, not every render.
    void Promise.allSettled(repos.map(async (repo) => ({
      repo, release: await getLatestRelease(repo),
    }))).then((results) => {
      if (cancelled) return;
      const next: Record<string, ReleaseInfo> = {};
      results.forEach((result) => {
        if (result.status === "fulfilled" && result.value.release) {
          next[result.value.repo] = result.value.release;
        }
      });
      setGithubReleases(next);
    });
    return () => { cancelled = true; };
  }, [ports]);

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
        <h1>Console Ports</h1>
        <p>Discover games and projects coming to PC from PlayStation, Xbox, Nintendo and other platforms. Search public port releases, separate community indexes, and full-build listings without relying on Steam catalogue IDs.</p>
        <p><strong>Live sources:</strong> Console Ports Index · GitHub releases · FitGirl article feed (listing metadata only)</p>
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
              {p.origin && <span>{p.origin}</span>}
              {p.buildType && <span>{p.buildType}</span>}
              {p.platforms.map((tag) => <span key={tag}>{tag}</span>)}
            </div>
            {githubProject(p.projectUrl) && githubReleases[githubProject(p.projectUrl)!] && (
              <div className="community-ports__release">
                <small>Latest GitHub release</small>
                <strong>{githubReleases[githubProject(p.projectUrl)!].name}</strong>
                <div className="community-ports__release-links">
                  <button type="button" onClick={() => void window.electron.openExternal(githubReleases[githubProject(p.projectUrl)!].url)}>View release ↗</button>
                  {githubReleases[githubProject(p.projectUrl)!].assets.slice(0, 3).map((asset) => (
                    <button type="button" key={asset.url} title={asset.name}
                      onClick={() => void window.electron.openExternal(asset.url)}>
                      {asset.name.length > 27 ? asset.name.slice(0, 24) + "…" : asset.name} ↗
                    </button>
                  ))}
                </div>
              </div>
            )}
            <div className="community-ports__actions">
              <button type="button" onClick={() => void window.electron.openExternal(p.projectUrl)}>
                {p.buildType === "Complete-build listing" ? "View listing ↗" : "Project website ↗"}
              </button>
              {p.source === "My entries" && <button type="button" className="community-ports__quiet"
                onClick={() => setSaved((prev) => ({ ...prev, custom: prev.custom.filter((x) => x.projectUrl !== p.projectUrl) }))}>Remove</button>}
            </div>
          </article>
        ))}
        {visible.length === 0 && <p>No matching projects. Try a different search or add an index.</p>}
      </div>
      <div className="community-ports__management">
        <section>
          <h2>Console Ports sources</h2>
          <p>The built-in index and GitHub release information refresh while Hydra is running (every six hours). Add more HTTPS JSON sources below. FitGirl RSS discovers public article listings, not installers or torrent links.</p>
          <p>FitGirl feed: {rssStatus}</p>
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
          <h2>Add a game or port</h2>
          <p>Save any non-Steam game or console-to-PC build listing locally. Links open the original publisher/project website; Hydra does not host or install game files from these entries.</p>
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
      <p className="community-ports__disclaimer">Source type matters: a GitHub executable may be an engine/launcher only, while a full-build listing is an external article, not a verified working release. Use original game assets where required and verify the legitimacy of third-party downloads. Your normal Hydra catalogue and download sources are unchanged.</p>
    </main>
  );
}
