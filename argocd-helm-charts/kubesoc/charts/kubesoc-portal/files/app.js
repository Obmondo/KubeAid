// kubesoc portal: renders /links.json. No HTML parsing anywhere: every value is
// set as text, and only http(s) URLs become links.
(function () {
  "use strict";

  function el(tag, attrs, children) {
    var e = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      if (k === "text") e.textContent = attrs[k];
      else e.setAttribute(k, attrs[k]);
    });
    (children || []).forEach(function (c) { if (c) e.appendChild(c); });
    return e;
  }

  function safeUrl(u) {
    try {
      var p = new URL(u, window.location.href);
      return p.protocol === "https:" || p.protocol === "http:" ? p.href : null;
    } catch (e) {
      return null;
    }
  }

  function link(l) {
    var href = safeUrl(l.url);
    if (!href) return null;
    return el("a", { href: href, rel: "noopener noreferrer", "class": "link" }, [
      el("span", { "class": "name", text: l.name || href }),
      l.description ? el("span", { "class": "desc", text: l.description }) : null,
    ]);
  }

  function norm(g) {
    return String(g).replace(/^role:/, "").replace(/^\//, "");
  }

  function show(id, on) {
    document.getElementById(id).hidden = !on;
  }

  function fail(msg) {
    var e = document.getElementById("error");
    e.textContent = msg;
    e.hidden = false;
  }

  function render(data, me) {
    if (data.title) document.getElementById("title").textContent = data.title;
    if (data.subtitle) document.getElementById("subtitle").textContent = data.subtitle;
    var central = document.getElementById("central");
    (data.central || []).forEach(function (l) {
      var a = link(l);
      if (a) central.appendChild(el("div", { "class": "card tool" }, [a]));
    });
    show("central-section", central.children.length > 0);

    var tenants = data.tenants || [];
    var scope = "Showing every tenant.";
    if (me && me.groups) {
      var mine = {};
      me.groups.forEach(function (g) { mine[norm(g)] = true; });
      var operator = (data.operatorRoles || []).some(function (r) { return mine[r]; });
      if (!operator) {
        tenants = tenants.filter(function (t) {
          return (t.roles || []).some(function (r) { return mine[r]; });
        });
        scope = "Showing the tenants you belong to.";
      }
    }
    document.getElementById("scope").textContent = scope;

    var box = document.getElementById("tenants");
    var cards = tenants.map(function (t) {
      var links = (t.links || []).map(link).filter(Boolean);
      var card = el("article", { "class": "card" }, [
        el("h3", {}, [el("span", { text: t.name || t.code }), el("span", { "class": "code", text: t.code || "" })]),
        el("div", { "class": "links" }, links),
      ]);
      card.dataset.key = ((t.name || "") + " " + (t.code || "")).toLowerCase();
      box.appendChild(card);
      return card;
    });
    show("empty", cards.length === 0);

    document.getElementById("filter").addEventListener("input", function (ev) {
      var q = ev.target.value.trim().toLowerCase();
      var n = 0;
      cards.forEach(function (c) {
        c.hidden = q !== "" && c.dataset.key.indexOf(q) < 0;
        if (!c.hidden) n++;
      });
      show("empty", n === 0);
    });
  }

  function getJson(url) {
    return fetch(url, { credentials: "same-origin", cache: "no-store" }).then(function (r) {
      if (!r.ok) throw new Error(url + ": HTTP " + r.status);
      return r.json();
    });
  }

  // oauth2-proxy's userinfo: {user, email, groups, preferredUsername}. Keycloak
  // realm roles arrive as "role:<name>". Without it (forward auth elsewhere),
  // every tenant is shown; the tools enforce access either way.
  var who = getJson("/oauth2/userinfo").catch(function () { return null; });
  Promise.all([getJson("/links.json"), who]).then(function (r) {
    var me = r[1];
    if (me) {
      document.getElementById("user").textContent = me.preferredUsername || me.email || me.user || "";
    } else {
      document.getElementById("signout").hidden = true;
    }
    render(r[0], me);
  }).catch(function (e) {
    fail("Could not load the links: " + e.message);
  });
})();
