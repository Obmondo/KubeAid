// Runs files/app.js against a minimal DOM and fake fetch: node tests/app_test.js
"use strict";
const fs = require("fs");
const path = require("path");
const assert = require("assert");

function makeEl(tag) {
  return {
    tag, children: [], attrs: {}, dataset: {}, hidden: false, textContent: "", listeners: {},
    setAttribute(k, v) { this.attrs[k] = v; },
    appendChild(c) { this.children.push(c); return c; },
    addEventListener(ev, fn) { this.listeners[ev] = fn; },
  };
}
const ids = {};
["title", "subtitle", "user", "signout", "central-section", "central", "scope", "tenants", "empty", "error", "filter"]
  .forEach((id) => { ids[id] = makeEl("div"); });

const LINKS = {
  title: "kubesoc", central: [{ name: "IRIS", url: "https://iris.example.com/" }, { name: "bad", url: "javascript:alert(1)" }],
  tenants: [
    { code: "001", name: "Tenant A", roles: ["tenant-001"], links: [{ name: "Wazuh", url: "https://wazuh-001.example.com/" }] },
    { code: "002", name: "Tenant B", roles: ["tenant-002"], links: [{ name: "Wazuh", url: "https://wazuh-002.example.com/" }] },
  ],
  operatorRoles: ["analyst"],
};

async function run(userinfo) {
  Object.values(ids).forEach((e) => { e.children = []; e.hidden = false; e.textContent = ""; });
  const ctx = {
    window: { location: { href: "https://portal.example.com/" } },
    URL,
    document: { getElementById: (id) => ids[id], createElement: makeEl },
    fetch: async (url) => {
      if (url === "/links.json") return { ok: true, json: async () => LINKS };
      if (url === "/oauth2/userinfo" && userinfo) return { ok: true, json: async () => userinfo };
      return { ok: false, status: 401 };
    },
  };
  const src = fs.readFileSync(path.join(__dirname, "..", "files", "app.js"), "utf8");
  new Function("window", "document", "fetch", "URL", src)(ctx.window, ctx.document, ctx.fetch, ctx.URL);
  await new Promise((r) => setTimeout(r, 20));
  return ids.tenants.children.map((c) => c.children[0].children[0].textContent);
}

(async () => {
  assert.deepStrictEqual(await run({ preferredUsername: "ana", groups: ["role:tenant-002"] }), ["Tenant B"]);
  assert.strictEqual(ids.user.textContent, "ana");
  assert.strictEqual(ids.central.children.length, 1, "javascript: URLs are dropped");
  assert.deepStrictEqual(await run({ user: "op", groups: ["role:analyst"] }), ["Tenant A", "Tenant B"]);
  assert.deepStrictEqual(await run(null), ["Tenant A", "Tenant B"], "no userinfo: show all");
  assert.strictEqual(ids.signout.hidden, true);
  assert.deepStrictEqual(await run({ groups: ["/tenant-001"] }), ["Tenant A"], "group paths match too");
  ids.filter.listeners.input({ target: { value: "zzz" } });
  assert.strictEqual(ids.empty.hidden, false);
  console.log("app_test: ok");
})().catch((e) => { console.error(e); process.exit(1); });
