#!/usr/bin/env python3
"""Sync Keycloak role and group membership into DFIR-IRIS.

IRIS's OIDC login reads only the username and email claims, so group and
customer membership cannot come from the token. This job makes Keycloak the
single place where access is granted and revoked:

  * every enabled Keycloak user whose realm roles or groups appear in the
    mapping gets an IRIS user (same login as the Keycloak username), with its
    IRIS groups and customers set to exactly what the mapping yields;
  * a user whose mapping yields no group or no customer is deactivated, and
    removed from every IRIS group the sync manages;
  * an IRIS user that no longer exists (or is disabled) in Keycloak is
    deactivated, unless its login is protected or it is a service account.

Standard library only, so it runs in the IRIS image. Dry run unless
DRY_RUN=false. Configuration from the environment:

  KEYCLOAK_URL            e.g. https://keycloak.example.com/auth
  KEYCLOAK_REALM          realm name
  KEYCLOAK_CLIENT_ID      confidential client with a service account that has
  KEYCLOAK_CLIENT_SECRET  realm-management view-users (read only)
  IRIS_URL                e.g. http://dfir-iris-app:8000
  IRIS_API_KEY            key of an IRIS user with server_administrator
  MAPPING_FILE            JSON, see README (default /config/mapping.json)
  PROTECTED_LOGINS        comma-separated IRIS logins never touched
  DEACTIVATE_ORPHANS      true|false (default true)
  DRY_RUN                 true|false (default true)
"""
import json
import os
import secrets
import string
import sys
import urllib.error
import urllib.parse
import urllib.request

ALL = "*"


def env(name, default=None, required=True):
    value = os.environ.get(name, default)
    if required and not value:
        sys.exit(f"missing environment variable {name}")
    return value


def truthy(value):
    return str(value).strip().lower() in ("1", "true", "yes", "on")


def request(method, url, headers=None, body=None, form=False):
    data = None
    headers = dict(headers or {})
    if body is not None:
        if form:
            data = urllib.parse.urlencode(body).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        else:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as err:
        detail = err.read()[:300].decode(errors="replace")
        raise RuntimeError(f"{method} {url.split('?')[0]} -> HTTP {err.code}: {detail}") from None
    return json.loads(raw) if raw else None


# --------------------------------------------------------------- Keycloak ---

class Keycloak:
    def __init__(self, base, realm, client_id, client_secret):
        self.base = base.rstrip("/")
        self.realm = realm
        token = request("POST", f"{self.base}/realms/{realm}/protocol/openid-connect/token",
                        body={"grant_type": "client_credentials", "client_id": client_id,
                              "client_secret": client_secret}, form=True)
        self.headers = {"Authorization": "Bearer " + token["access_token"]}

    def get(self, path):
        return request("GET", f"{self.base}/admin/realms/{self.realm}{path}", self.headers)

    def users(self):
        """Enabled human users with their realm roles and group names."""
        out, first, page = [], 0, 100
        while True:
            batch = self.get(f"/users?first={first}&max={page}&briefRepresentation=true")
            for u in batch:
                if not u.get("enabled", True) or u["username"].startswith("service-account-"):
                    continue
                uid = u["id"]
                roles = {r["name"] for r in self.get(f"/users/{uid}/role-mappings/realm/composite")}
                groups = {g["name"] for g in self.get(f"/users/{uid}/groups?briefRepresentation=true")}
                out.append({"username": u["username"], "email": u.get("email") or "",
                            "name": " ".join(p for p in (u.get("firstName"), u.get("lastName")) if p)
                                    or u["username"],
                            "roles": roles, "groups": groups})
            if len(batch) < page:
                return out
            first += page


# ------------------------------------------------------------------- IRIS ---

def pick(item, *keys):
    for key in keys:
        if key in item:
            return item[key]
    raise KeyError(f"none of {keys} in {sorted(item)}")


class Iris:
    def __init__(self, base, api_key, dry_run):
        self.base = base.rstrip("/")
        self.headers = {"Authorization": "Bearer " + api_key}
        self.dry_run = dry_run

    def call(self, method, path, body=None, write=False):
        if write and self.dry_run:
            return None
        resp = request(method, self.base + path, self.headers, body)
        if isinstance(resp, dict) and resp.get("status") not in (None, "success"):
            raise RuntimeError(f"{method} {path}: {resp.get('message')}")
        return resp.get("data") if isinstance(resp, dict) else resp

    def groups(self):
        return {pick(g, "group_name", "name"): pick(g, "group_id", "id")
                for g in self.call("GET", "/manage/groups/list")}

    def customers(self):
        return {pick(c, "customer_name", "name"): pick(c, "customer_id", "client_id", "id")
                for c in self.call("GET", "/manage/customers/list")}

    def users(self):
        return self.call("GET", "/manage/users/list")

    def user(self, uid):
        return self.call("GET", f"/manage/users/{uid}")


def ids_of(entries, *keys):
    return {pick(e, *keys) for e in (entries or [])}


def random_password():
    # Never used: SSO users sign in through Keycloak. Satisfies any IRIS policy.
    alphabet = string.ascii_letters + string.digits + "!#%+-=_"
    core = "".join(secrets.choice(alphabet) for _ in range(40))
    return core + "Aa1!"


# ------------------------------------------------------------------- sync ---

def desired(kc_user, mapping, all_customers):
    groups, customers = set(), set()
    for kind, names in (("roles", kc_user["roles"]), ("groups", kc_user["groups"])):
        for name in names:
            rule = mapping.get(kind, {}).get(name)
            if not rule:
                continue
            groups.update(rule.get("groups", []))
            for c in rule.get("customers", []):
                if c == ALL:
                    customers.update(all_customers)
                else:
                    customers.add(c)
    return groups, customers


def main():
    dry_run = truthy(env("DRY_RUN", "true"))
    deactivate_orphans = truthy(env("DEACTIVATE_ORPHANS", "true"))
    protected = {p.strip() for p in env("PROTECTED_LOGINS", "", required=False).split(",") if p.strip()}
    with open(env("MAPPING_FILE", "/config/mapping.json")) as fh:
        mapping = json.load(fh)

    kc = Keycloak(env("KEYCLOAK_URL"), env("KEYCLOAK_REALM"),
                  env("KEYCLOAK_CLIENT_ID"), env("KEYCLOAK_CLIENT_SECRET"))
    iris = Iris(env("IRIS_URL"), env("IRIS_API_KEY"), dry_run)

    iris_groups = iris.groups()
    iris_customers = iris.customers()
    managed_group_names = {g for kind in ("roles", "groups")
                           for rule in mapping.get(kind, {}).values() for g in rule.get("groups", [])}
    for name in sorted(managed_group_names - set(iris_groups)):
        print(f"WARN mapping names IRIS group {name!r}, which does not exist; ignored")
    for kind in ("roles", "groups"):
        for rule in mapping.get(kind, {}).values():
            for c in rule.get("customers", []):
                if c != ALL and c not in iris_customers:
                    print(f"WARN mapping names IRIS customer {c!r}, which does not exist; ignored")
    managed_group_ids = {iris_groups[g] for g in managed_group_names if g in iris_groups}

    by_login = {u["user_login"]: u for u in iris.users()}
    kc_users = kc.users()
    kc_logins = {u["username"] for u in kc_users}
    changes = errors = 0
    mode = "DRY-RUN" if dry_run else "APPLY"
    print(f"{mode}: {len(kc_users)} Keycloak users, {len(by_login)} IRIS users, "
          f"{len(iris_groups)} IRIS groups, {len(iris_customers)} IRIS customers")

    def act(msg, fn):
        nonlocal changes, errors
        changes += 1
        print(f"{mode} {msg}")
        if dry_run:
            return None
        try:
            return fn()
        except Exception as exc:  # keep going; report at the end
            errors += 1
            print(f"ERROR {msg}: {exc}")
            return None

    for ku in sorted(kc_users, key=lambda u: u["username"]):
        login = ku["username"]
        if login in protected:
            print(f"WARN Keycloak user {login!r} collides with a protected IRIS login; skipped. "
                  f"An SSO login with this name would sign in as that IRIS account.")
            continue
        want_groups, want_customers = desired(ku, mapping, set(iris_customers))
        want_group_ids = {iris_groups[g] for g in want_groups if g in iris_groups}
        want_customer_ids = {iris_customers[c] for c in want_customers if c in iris_customers}
        should_be_active = bool(want_group_ids) and bool(want_customer_ids)
        iu = by_login.get(login)

        if iu is None:
            if not should_be_active:
                continue
            created = act(f"create {login} ({ku['email'] or 'no email'})",
                          lambda: iris.call("POST", "/manage/users/add", {
                              "user_login": login, "user_name": ku["name"],
                              "user_email": ku["email"] or f"{login}@invalid.local",
                              "user_password": random_password(),
                              "user_is_service_account": False}, write=True))
            if dry_run:
                print(f"{mode}   then groups {sorted(want_groups)} customers {sorted(want_customers)}")
                continue
            if not created:
                continue
            uid, cur_groups, cur_customers, active = pick(created, "user_id", "id"), set(), set(), True
        else:
            if iu.get("user_is_service_account"):
                continue
            uid = iu["user_id"]
            details = iris.user(uid)
            cur_groups = ids_of(details.get("user_groups"), "group_id", "id")
            cur_customers = ids_of(details.get("user_customers"), "customer_id", "client_id", "id")
            active = bool(details.get("user_active"))

        if should_be_active:
            if not active:
                act(f"activate {login}", lambda: iris.call("GET", f"/manage/users/activate/{uid}", write=True))
            # keep groups the sync does not manage (added by hand), replace the managed ones
            target_groups = (cur_groups - managed_group_ids) | want_group_ids
            if target_groups != cur_groups:
                act(f"groups {login}: {sorted(cur_groups)} -> {sorted(target_groups)}",
                    lambda: iris.call("POST", f"/manage/users/{uid}/groups/update",
                                      {"groups_membership": sorted(target_groups)}, write=True))
            if want_customer_ids != cur_customers:
                act(f"customers {login}: {sorted(cur_customers)} -> {sorted(want_customer_ids)}",
                    lambda: iris.call("POST", f"/manage/users/{uid}/customers/update",
                                      {"customers_membership": sorted(want_customer_ids)}, write=True))
        else:
            for gid in sorted(cur_groups & managed_group_ids):
                act(f"remove {login} from group {gid}",
                    lambda gid=gid: iris.call("POST", f"/manage/groups/{gid}/members/delete/{uid}", write=True))
            if active:
                act(f"deactivate {login} (no mapped group or customer in Keycloak)",
                    lambda: iris.call("GET", f"/manage/users/deactivate/{uid}", write=True))

    if deactivate_orphans:
        for login, iu in sorted(by_login.items()):
            if login in kc_logins or login in protected or iu.get("user_is_service_account"):
                continue
            if iu.get("user_active"):
                act(f"deactivate {login} (not an enabled Keycloak user)",
                    lambda uid=iu["user_id"]: iris.call("GET", f"/manage/users/deactivate/{uid}", write=True))

    print(f"{mode} done: {changes} change(s), {errors} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
