import { ipcMain } from "electron";

/**
 * Metadata-only feed adapter for the official repack site's public RSS.
 * No torrent/magnet/installer links are parsed, proxied or downloaded.
 * Fixed URL prevents arbitrary remote requests through this IPC handler.
 */
const PUBLIC_FEED_URL = "https://fitgirl-repacks.site/feed/";
const MAX_BYTES = 1024 * 1024;

ipcMain.handle("getConsolePortsRss", async () => {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(PUBLIC_FEED_URL, {
      method: "GET",
      headers: {
        Accept: "application/rss+xml, application/xml, text/xml",
        "User-Agent": "Mozilla/5.0 Hydra-Console-Ports-Indexer/1.0",
      },
      signal: controller.signal,
    });
    if (!response.ok) throw new Error("Source HTTP " + response.status);
    const contentType = response.headers.get("content-type") ?? "";
    if (!/xml|rss|text\/plain/i.test(contentType)) {
      throw new Error("Expected XML/RSS feed; received " + contentType);
    }
    const declared = Number(response.headers.get("content-length") || 0);
    if (declared > MAX_BYTES) throw new Error("Source feed too large");
    const reader = response.body?.getReader();
    if (!reader) throw new Error("Source feed has no body");
    const chunks: Uint8Array[] = [];
    let count = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        count += value.byteLength;
        if (count > MAX_BYTES) throw new Error("Source feed too large");
        chunks.push(value);
      }
    } finally {
      reader.releaseLock();
    }
    const result = new Uint8Array(count);
    let offset = 0;
    for (const chunk of chunks) {
      result.set(chunk, offset);
      offset += chunk.length;
    }
    return new TextDecoder().decode(result);
  } finally {
    clearTimeout(timeout);
  }
});
