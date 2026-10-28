#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SQLite 数据库查看器（零依赖单文件版）

用法:
    python sqlite_viewer.py /path/to/database.db
    python sqlite_viewer.py data.db --host 0.0.0.0 --port 8080

浏览器打开 http://127.0.0.1:8000
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import urllib.parse
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DB_PATH = "data.db"
RESERVED = {"limit", "offset", "sort", "dir", "q"}
MAX_TEXT = 2000000


# ---------------------------------------------------------------- 数据库工具

def q(ident: str) -> str:
    """安全地引用一个标识符"""
    return '"' + str(ident).replace('"', '""') + '"'


@contextmanager
def db():
    """以只读方式打开数据库"""
    uri = Path(DB_PATH).resolve().as_uri() + "?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def jsonable(v, limit=MAX_TEXT):
    if isinstance(v, (bytes, bytearray, memoryview)):
        b = bytes(v)
        return f"<BLOB {len(b)} bytes> {b[:32].hex()}"
    if isinstance(v, str) and limit and len(v) > limit:
        return v[:limit] + f"\n…[已截断，完整长度 {len(v)} 字符，点击行查看全文]"
    return v


def table_names(conn):
    return [r[0] for r in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name"
    )]


def table_info(conn, table):
    out = []
    for r in conn.execute(f"PRAGMA table_info({q(table)})"):
        out.append({
            "name": r["name"],
            "type": r["type"] or "",
            "notnull": bool(r["notnull"]),
            "pk": bool(r["pk"]),
            "default": r["dflt_value"],
        })
    return out


def foreign_keys(conn, table):
    out = []
    for r in conn.execute(f"PRAGMA foreign_key_list({q(table)})"):
        out.append({
            "column": r["from"],
            "ref_table": r["table"],
            "ref_column": r["to"] or "id",
            "on_delete": r["on_delete"],
        })
    return out


def full_schema(conn):
    tables = []
    for t in table_names(conn):
        try:
            count = conn.execute(f"SELECT COUNT(*) FROM {q(t)}").fetchone()[0]
        except sqlite3.Error:
            count = None
        tables.append({
            "name": t,
            "columns": table_info(conn, t),
            "foreign_keys": foreign_keys(conn, t),
            "count": count,
        })
    return tables


def coerce(value, coltype):
    t = (coltype or "").upper()
    if "INT" in t:
        try:
            return int(value)
        except (TypeError, ValueError):
            return value
    if any(k in t for k in ("REAL", "FLOA", "DOUB", "NUM", "DEC")):
        try:
            return float(value)
        except (TypeError, ValueError):
            return value
    return value


def build_conditions(params, cols):
    colmap = {c["name"]: c for c in cols}
    where, args = [], []

    for key, values in params.items():
        if key in RESERVED or key not in colmap:
            continue
        val = values[-1]
        if val == "":
            continue
        where.append(f"{q(key)} = ?")
        args.append(coerce(val, colmap[key]["type"]))

    search = (params.get("q") or [""])[-1].strip()
    if search:
        like = f"%{search}%"
        parts = [f"CAST({q(c['name'])} AS TEXT) LIKE ?" for c in cols]
        if parts:
            where.append("(" + " OR ".join(parts) + ")")
            args.extend([like] * len(parts))

    return where, args


def fetch_rows(conn, table, params):
    cols = table_info(conn, table)
    colnames = [c["name"] for c in cols]
    where, args = build_conditions(params, cols)
    where_sql = (" WHERE " + " AND ".join(where)) if where else ""

    try:
        limit = int((params.get("limit") or ["50"])[-1])
    except ValueError:
        limit = 50
    try:
        offset = int((params.get("offset") or ["0"])[-1])
    except ValueError:
        offset = 0
    limit = max(1, min(limit, 500))
    offset = max(0, offset)

    sort = (params.get("sort") or [None])[-1]
    direction = ((params.get("dir") or ["asc"])[-1] or "asc").lower()
    if direction not in ("asc", "desc"):
        direction = "asc"

    if sort in colnames:
        order_sql = f" ORDER BY {q(sort)} {direction.upper()}"
    else:
        pks = [c["name"] for c in cols if c["pk"]]
        order_sql = f" ORDER BY {q(pks[0])} DESC" if pks else ""
        sort = None

    total = conn.execute(
        f"SELECT COUNT(*) FROM {q(table)}{where_sql}", args
    ).fetchone()[0]

    rows = conn.execute(
        f"SELECT * FROM {q(table)}{where_sql}{order_sql} LIMIT ? OFFSET ?",
        args + [limit, offset],
    ).fetchall()

    return {
        "table": table,
        "columns": cols,
        "rows": [{k: jsonable(r[k]) for k in colnames} for r in rows],
        "total": total,
        "limit": limit,
        "offset": offset,
        "sort": sort,
        "dir": direction,
    }


def fetch_row(conn, table, params):
    cols = table_info(conn, table)
    colmap = {c["name"]: c for c in cols}
    where, args = [], []
    for key, values in params.items():
        if key not in colmap:
            continue
        where.append(f"{q(key)} = ?")
        args.append(coerce(values[-1], colmap[key]["type"]))
    if not where:
        return None
    row = conn.execute(
        f"SELECT * FROM {q(table)} WHERE {' AND '.join(where)} LIMIT 1", args
    ).fetchone()
    if row is None:
        return None
    return {k: jsonable(row[k], limit=0) for k in row.keys()}


READONLY_RE = re.compile(r"^\s*(SELECT|WITH|PRAGMA|EXPLAIN)\b", re.IGNORECASE)


def run_query(conn, sql):
    if not READONLY_RE.match(sql):
        raise ValueError("仅允许只读查询：SELECT / WITH / PRAGMA / EXPLAIN")
    cur = conn.execute(sql)
    if cur.description is None:
        return {"columns": [], "rows": []}
    columns = [d[0] for d in cur.description]
    rows = cur.fetchmany(1000)
    return {
        "columns": columns,
        "rows": [[jsonable(v) for v in r] for r in rows],
    }


# ---------------------------------------------------------------- HTTP 服务

class Handler(BaseHTTPRequestHandler):
    server_version = "SQLiteViewer/1.0"

    def log_message(self, fmt, *args):
        sys.stderr.write("[%s] %s\n" % (self.address_string(), fmt % args))

    # -- helpers
    def _send(self, status, body, ctype="application/json; charset=utf-8"):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, status, obj):
        self._send(status, json.dumps(obj, ensure_ascii=False, default=str))

    # -- GET
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = urllib.parse.unquote(parsed.path)
        params = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)

        try:
            if path in ("/", "/index.html"):
                return self._send(200, INDEX_HTML, "text/html; charset=utf-8")

            if path == "/api/schema":
                with db() as conn:
                    return self._json(200, {"tables": full_schema(conn)})

            m = re.match(r"^/api/table/(.+)$", path)
            if m:
                with db() as conn:
                    return self._json(200, fetch_rows(conn, m.group(1), params))

            m = re.match(r"^/api/row/(.+)$", path)
            if m:
                with db() as conn:
                    row = fetch_row(conn, m.group(1), params)
                if row is None:
                    return self._json(404, {"error": "未找到记录"})
                return self._json(200, {"row": row})

            return self._json(404, {"error": "Not Found"})

        except sqlite3.Error as e:
            return self._json(400, {"error": f"SQLite 错误: {e}"})
        except Exception as e:  # noqa: BLE001
            return self._json(500, {"error": str(e)})

    # -- POST
    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/api/query":
            return self._json(404, {"error": "Not Found"})
        try:
            length = int(self.headers.get("Content-Length") or 0)
            payload = json.loads(self.rfile.read(length) or b"{}")
            sql = (payload.get("sql") or "").strip()
            if not sql:
                return self._json(400, {"error": "SQL 不能为空"})
            with db() as conn:
                result = run_query(conn, sql)
            return self._json(200, result)
        except sqlite3.Error as e:
            return self._json(400, {"error": f"SQLite 错误: {e}"})
        except ValueError as e:
            return self._json(400, {"error": str(e)})
        except Exception as e:  # noqa: BLE001
            return self._json(500, {"error": str(e)})


# ---------------------------------------------------------------- 前端页面

INDEX_HTML = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>SQLite 查看器</title>
<style>
* { box-sizing: border-box; }
:root {
  --bg:#0e1116; --panel:#151a22; --panel2:#1b2230; --border:#252d3a;
  --text:#e5e9f0; --muted:#8b95a7; --accent:#4f9cf9;
  --null:#6b7486; --num:#7ee0a8; --str:#e8c07d;
}
html, body { height:100%; margin:0; }
body {
  background:var(--bg); color:var(--text); overflow:hidden;
  font:13.5px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;
}
#app { display:flex; height:100vh; }

/* ---------- 侧边栏 ---------- */
#sidebar {
  width:230px; flex:0 0 230px; background:var(--panel);
  border-right:1px solid var(--border); display:flex; flex-direction:column;
}
.brand { padding:14px 16px; border-bottom:1px solid var(--border); font-weight:600; font-size:14px; }
.brand small { display:block; color:var(--muted); font-weight:400; font-size:11px; margin-top:2px;
  overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
#table-list { list-style:none; margin:0; padding:8px; overflow-y:auto; flex:1; }
.table-item {
  display:flex; align-items:center; justify-content:space-between; gap:8px;
  padding:7px 10px; border-radius:6px; cursor:pointer; user-select:none;
}
.table-item:hover { background:var(--panel2); }
.table-item.active { background:var(--accent); color:#fff; }
.table-item.active .tcount { color:#dbe9ff; background:rgba(255,255,255,.15); }
.tname { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.tcount { font-size:11px; color:var(--muted); background:rgba(255,255,255,.06); padding:1px 7px; border-radius:10px; }
.sidebar-foot { padding:10px; border-top:1px solid var(--border); }

/* ---------- 主区域 ---------- */
#main { flex:1; display:flex; flex-direction:column; min-width:0; }
.panel { flex:1; display:flex; flex-direction:column; min-height:0; }
.toolbar {
  display:flex; align-items:center; gap:8px; padding:10px 14px;
  border-bottom:1px solid var(--border); background:var(--panel); flex-wrap:wrap;
}
input, select, button, textarea {
  font-family:inherit; font-size:13px; color:var(--text);
  background:var(--panel2); border:1px solid var(--border);
  border-radius:6px; padding:6px 10px; outline:none;
}
input:focus, textarea:focus, select:focus { border-color:var(--accent); }
button { cursor:pointer; }
button:hover:not(:disabled) { border-color:var(--accent); color:#fff; }
button.primary { background:var(--accent); border-color:var(--accent); color:#fff; }
button.primary:hover { background:#3d8ae6; }
button:disabled { opacity:.4; cursor:not-allowed; }

/* ---------- 表格 ---------- */
.table-wrap { flex:1; overflow:auto; }
table { border-collapse:separate; border-spacing:0; width:100%; font-size:12.5px; }
thead th {
  position:sticky; top:0; z-index:2; background:var(--panel2); text-align:left;
  white-space:nowrap; padding:8px 10px; border-bottom:1px solid var(--border);
  font-weight:600; cursor:pointer; user-select:none;
}
thead th:hover { color:var(--accent); }
tbody td {
  padding:6px 10px; border-bottom:1px solid rgba(255,255,255,.04);
  vertical-align:top; max-width:420px;
  overflow:hidden; text-overflow:ellipsis; white-space:nowrap;
}
tbody tr { cursor:pointer; }
tbody tr:hover { background:rgba(79,156,249,.08); }
td.rownum, th.rownum { width:56px; color:var(--muted); text-align:right; font-variant-numeric:tabular-nums; }
td.col-num { color:var(--num); text-align:right; font-variant-numeric:tabular-nums; }
td.col-str { color:var(--str); }
.null { color:var(--null); font-style:italic; }
.fk-link { color:var(--accent); cursor:pointer; border-bottom:1px dashed rgba(79,156,249,.5); }
.fk-link:hover { color:#8fc2ff; }
.badge { font-size:9px; padding:0 4px; border-radius:3px; margin-left:5px; vertical-align:middle; font-weight:600; }
.badge.pk { background:rgba(124,92,255,.2); color:#b39cff; }
.badge.fk { background:rgba(79,156,249,.2); color:#8fc2ff; }
.sort-ind { margin-left:5px; color:var(--accent); }

/* ---------- 分页 ---------- */
.pager {
  display:flex; align-items:center; gap:8px; padding:8px 14px;
  border-top:1px solid var(--border); background:var(--panel);
  font-size:12.5px; color:var(--muted);
}
.pager .spacer { flex:1; }

/* ---------- 弹窗 ---------- */
.overlay {
  position:fixed; inset:0; background:rgba(0,0,0,.62); z-index:50; padding:24px;
  display:flex; align-items:center; justify-content:center;
}
.modal {
  background:var(--panel); border:1px solid var(--border); border-radius:10px;
  width:min(920px,100%); max-height:85vh; display:flex; flex-direction:column;
  box-shadow:0 20px 60px rgba(0,0,0,.55);
}
.modal-head { display:flex; align-items:center; gap:10px; padding:12px 16px; border-bottom:1px solid var(--border); }
.modal-head h2 { margin:0; font-size:14px; flex:1; font-weight:600; }
.modal-body { padding:12px 16px; overflow:auto; }
.field { margin-bottom:14px; }
.field label { display:block; font-size:11.5px; color:var(--muted); margin-bottom:4px; }
.field .type { color:#5a6478; margin-left:6px; }
.field pre {
  margin:0; background:var(--panel2); border:1px solid var(--border); border-radius:6px;
  padding:8px 10px; white-space:pre-wrap; word-break:break-word;
  font:12.5px/1.55 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
  max-height:320px; overflow:auto;
}
.field pre.null-val { color:var(--null); font-style:italic; }

/* ---------- SQL 面板 ---------- */
#sql-input {
  width:100%; min-height:110px; resize:vertical;
  font:12.5px/1.6 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
}
.sql-toolbar { flex-direction:column; align-items:stretch; }
.sql-toolbar .row { display:flex; gap:10px; align-items:center; }
.sql-result { flex:1; overflow:hidden; display:flex; flex-direction:column; }
.hint { color:var(--muted); font-size:12px; }
.empty { padding:40px; text-align:center; color:var(--muted); }
.err { color:#ff7b72; padding:14px; white-space:pre-wrap; font-family:ui-monospace,monospace; }
</style>
</head>
<body>
<div id="app">
  <aside id="sidebar">
    <div class="brand">SQLite 查看器<small id="db-label">—</small></div>
    <ul id="table-list"></ul>
    <div class="sidebar-foot">
      <button id="sql-btn" style="width:100%">SQL 查询</button>
    </div>
  </aside>

  <main id="main">
    <!-- 表格视图 -->
    <div class="panel" id="table-panel">
      <div class="toolbar">
        <strong id="cur-table" style="font-size:14px">—</strong>
        <input type="search" id="search" placeholder="全局搜索…" style="width:220px">
        <button id="refresh-btn">刷新</button>
        <span class="spacer" style="flex:1"></span>
        <span class="hint">点表头排序 · 点行看全文 · 点蓝色值跳转外键</span>
        <select id="page-size">
          <option value="25">25 条/页</option>
          <option value="50" selected>50 条/页</option>
          <option value="100">100 条/页</option>
          <option value="200">200 条/页</option>
        </select>
      </div>
      <div class="table-wrap">
        <table>
          <thead><tr id="thead-row"></tr></thead>
          <tbody id="tbody"></tbody>
        </table>
        <div id="empty-tip" class="empty" style="display:none">没有数据</div>
      </div>
      <div class="pager">
        <span id="pager-info">—</span>
        <span class="spacer"></span>
        <button id="first-btn">« 首页</button>
        <button id="prev-btn">‹ 上一页</button>
        <button id="next-btn">下一页 ›</button>
        <button id="last-btn">末页 »</button>
      </div>
    </div>

    <!-- SQL 视图 -->
    <div class="panel" id="sql-panel" style="display:none">
      <div class="toolbar sql-toolbar">
        <textarea id="sql-input" placeholder="SELECT * FROM sessions LIMIT 20;"></textarea>
        <div class="row">
          <button class="primary" id="sql-run">执行 (Ctrl+Enter)</button>
          <span class="hint">只读：SELECT / WITH / PRAGMA / EXPLAIN</span>
        </div>
      </div>
      <div class="sql-result" id="sql-result">
        <div class="empty">在上方输入 SQL 并执行</div>
      </div>
    </div>
  </main>
</div>
<div id="modal-root"></div>

<script>
const $ = s => document.querySelector(s);

const state = {
  tables: [], table: null, filters: {}, search: "",
  sort: null, dir: "asc", limit: 50, offset: 0, total: 0, view: "table",
};

/* ---------------- 工具 ---------------- */
async function api(url, opts) {
  const res = await fetch(url, opts);
  const text = await res.text();
  let data;
  try { data = JSON.parse(text); }
  catch { throw new Error(text.slice(0, 300) || res.statusText); }
  if (!res.ok) throw new Error(data.error || res.statusText);
  return data;
}

function typeClass(t) {
  const u = (t || "").toUpperCase();
  if (u.includes("INT")) return "num";
  if (/(REAL|FLOA|DOUB|NUM|DEC)/.test(u)) return "num";
  if (u.includes("BLOB")) return "blob";
  return "str";
}

function highlightSidebar() {
  document.querySelectorAll(".table-item").forEach(li =>
    li.classList.toggle("active", li.dataset.table === state.table));
}

/* ---------------- 初始化 ---------------- */
async function init() {
  const data = await api("/api/schema");
  state.tables = data.tables;

  const list = $("#table-list");
  list.innerHTML = "";
  for (const t of state.tables) {
    const li = document.createElement("li");
    li.className = "table-item";
    li.dataset.table = t.name;
    const nm = document.createElement("span");
    nm.className = "tname";
    nm.textContent = t.name;
    const ct = document.createElement("span");
    ct.className = "tcount";
    ct.textContent = t.count == null ? "-" : t.count;
    li.append(nm, ct);
    li.onclick = () => openTable(t.name);
    list.append(li);
  }

  if (state.tables.length) openTable(state.tables[0].name);
  else $("#empty-tip").style.display = "block";
}

/* ---------------- 表视图 ---------------- */
function openTable(name) {
  state.table = name;
  state.filters = {};
  state.search = "";
  state.sort = null;
  state.dir = "asc";
  state.offset = 0;
  $("#search").value = "";
  $("#cur-table").textContent = name;
  highlightSidebar();
  loadRows();
}

async function loadRows() {
  if (!state.table) return;
  const p = new URLSearchParams();
  p.set("limit", state.limit);
  p.set("offset", state.offset);
  if (state.sort) { p.set("sort", state.sort); p.set("dir", state.dir); }
  if (state.search) p.set("q", state.search);
  for (const [k, v] of Object.entries(state.filters)) p.set(k, v);

  try {
    const data = await api(`/api/table/${encodeURIComponent(state.table)}?${p}`);
    renderTable(data);
  } catch (e) {
    $("#tbody").innerHTML = "";
    $("#pager-info").textContent = "错误: " + e.message;
  }
}

function renderTable(data) {
  state.total = data.total;

  const meta = state.tables.find(t => t.name === data.table);
  const fkByCol = {};
  if (meta) for (const fk of meta.foreign_keys) fkByCol[fk.column] = fk;

  /* 表头 */
  const thead = $("#thead-row");
  thead.innerHTML = "";
  const thNum = document.createElement("th");
  thNum.className = "rownum";
  thNum.textContent = "#";
  thead.append(thNum);

  for (const c of data.columns) {
    const th = document.createElement("th");
    th.append(document.createTextNode(c.name));
    if (c.pk) { const b = document.createElement("span"); b.className = "badge pk"; b.textContent = "PK"; th.append(b); }
    if (fkByCol[c.name]) { const b = document.createElement("span"); b.className = "badge fk"; b.textContent = "FK"; th.append(b); }
    if (data.sort === c.name) {
      const s = document.createElement("span");
      s.className = "sort-ind";
      s.textContent = data.dir === "asc" ? "▲" : "▼";
      th.append(s);
    }
    th.onclick = () => toggleSort(c.name);
    thead.append(th);
  }

  /* 表体 */
  const tbody = $("#tbody");
  tbody.innerHTML = "";
  data.rows.forEach((row, i) => {
    const tr = document.createElement("tr");
    const tdNum = document.createElement("td");
    tdNum.className = "rownum";
    tdNum.textContent = data.offset + i + 1;
    tr.append(tdNum);

    for (const c of data.columns) {
      const td = document.createElement("td");
      td.className = "col-" + typeClass(c.type);
      const v = row[c.name];

      if (v === null || v === undefined) {
        const sp = document.createElement("span");
        sp.className = "null";
        sp.textContent = "NULL";
        td.append(sp);
      } else if (fkByCol[c.name] && typeof v !== "object") {
        const a = document.createElement("span");
        a.className = "fk-link";
        a.textContent = String(v);
        a.onclick = ev => { ev.stopPropagation(); gotoParent(fkByCol[c.name], v); };
        td.append(a);
      } else {
        const s = typeof v === "object" ? JSON.stringify(v) : String(v);
        td.textContent = s.length > 120 ? s.slice(0, 120) + "…" : s;
        if (s.length > 120) td.title = s.slice(0, 1000);
      }
      tr.append(td);
    }
    tr.onclick = () => showDetail(data.table, row);
    tbody.append(tr);
  });

  $("#empty-tip").style.display = data.rows.length ? "none" : "block";

  const from = data.total === 0 ? 0 : data.offset + 1;
  const to = data.offset + data.rows.length;
  $("#pager-info").textContent = `共 ${data.total} 条 · 显示 ${from}-${to}`;
  $("#first-btn").disabled = $("#prev-btn").disabled = data.offset <= 0;
  $("#next-btn").disabled = $("#last-btn").disabled = to >= data.total;
}

function toggleSort(col) {
  if (state.sort === col) state.dir = state.dir === "asc" ? "desc" : "asc";
  else { state.sort = col; state.dir = "asc"; }
  state.offset = 0;
  loadRows();
}

function gotoParent(fk, value) {
  state.table = fk.ref_table;
  state.filters = {};
  state.filters[fk.ref_column] = value;
  state.search = "";
  state.sort = null;
  state.offset = 0;
  $("#search").value = "";
  $("#cur-table").textContent = `${fk.ref_table}  ←  ${fk.column} = ${value}`;
  highlightSidebar();
  loadRows();
}

/* ---------------- 行详情弹窗 ---------------- */
async function showDetail(tableName, row) {
  const meta = state.tables.find(t => t.name === tableName);
  const pkCols = meta ? meta.columns.filter(c => c.pk) : [];

  let full = row;
  if (pkCols.length && pkCols.every(c => row[c.name] !== undefined && row[c.name] !== null)) {
    const p = new URLSearchParams();
    pkCols.forEach(c => p.set(c.name, row[c.name]));
    try {
      const r = await api(`/api/row/${encodeURIComponent(tableName)}?${p}`);
      if (r.row) full = r.row;
    } catch (e) { /* 忽略，用截断数据 */ }
  }
  renderModal(tableName, full, meta);
}

function renderModal(tableName, row, meta) {
  const root = $("#modal-root");
  root.innerHTML = "";

  const overlay = document.createElement("div");
  overlay.className = "overlay";
  overlay.onclick = ev => { if (ev.target === overlay) root.innerHTML = ""; };

  const box = document.createElement("div");
  box.className = "modal";

  const head = document.createElement("div");
  head.className = "modal-head";
  const h2 = document.createElement("h2");
  const pkText = meta ? meta.columns.filter(c => c.pk).map(c => `${c.name}=${row[c.name]}`).join(", ") : "";
  h2.textContent = tableName + (pkText ? `  (${pkText})` : "");
  const closeBtn = document.createElement("button");
  closeBtn.textContent = "关闭";
  closeBtn.onclick = () => root.innerHTML = "";
  head.append(h2, closeBtn);

  const body = document.createElement("div");
  body.className = "modal-body";

  const colNames = meta ? meta.columns.map(c => c.name) : Object.keys(row);
  for (const key of colNames) {
    const colMeta = meta ? meta.columns.find(c => c.name === key) : null;
    const field = document.createElement("div");
    field.className = "field";

    const label = document.createElement("label");
    label.append(document.createTextNode(key));
    if (colMeta && colMeta.type) {
      const t = document.createElement("span");
      t.className = "type";
      t.textContent = colMeta.type;
      label.append(t);
    }

    const pre = document.createElement("pre");
    const v = row[key];
    if (v === null || v === undefined) {
      pre.textContent = "NULL";
      pre.classList.add("null-val");
    } else {
      pre.textContent = typeof v === "object" ? JSON.stringify(v, null, 2) : String(v);
    }

    field.append(label, pre);
    body.append(field);
  }

  box.append(head, body);
  overlay.append(box);
  root.append(overlay);

  const onEsc = e => {
    if (e.key === "Escape") { root.innerHTML = ""; document.removeEventListener("keydown", onEsc); }
  };
  document.addEventListener("keydown", onEsc);
}

/* ---------------- 分页 / 搜索 ---------------- */
$("#refresh-btn").onclick = () => loadRows();
$("#page-size").onchange = e => { state.limit = +e.target.value; state.offset = 0; loadRows(); };
$("#first-btn").onclick = () => { state.offset = 0; loadRows(); };
$("#prev-btn").onclick = () => { state.offset = Math.max(0, state.offset - state.limit); loadRows(); };
$("#next-btn").onclick = () => { state.offset += state.limit; loadRows(); };
$("#last-btn").onclick = () => {
  state.offset = Math.max(0, Math.ceil(state.total / state.limit) - 1) * state.limit;
  loadRows();
};

let searchTimer;
$("#search").oninput = e => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    state.search = e.target.value.trim();
    state.offset = 0;
    loadRows();
  }, 300);
};

/* ---------------- SQL 视图 ---------------- */
$("#sql-btn").onclick = () => {
  state.view = state.view === "sql" ? "table" : "sql";
  $("#table-panel").style.display = state.view === "table" ? "flex" : "none";
  $("#sql-panel").style.display = state.view === "sql" ? "flex" : "none";
  $("#sql-btn").textContent = state.view === "sql" ? "返回表格" : "SQL 查询";
  if (state.view === "sql") $("#sql-input").focus();
};

async function runSql() {
  const sql = $("#sql-input").value.trim();
  if (!sql) return;
  const out = $("#sql-result");
  out.innerHTML = '<div class="empty">执行中…</div>';
  try {
    const data = await api("/api/query", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sql }),
    });
    renderSqlResult(out, data);
  } catch (e) {
    out.innerHTML = "";
    const d = document.createElement("div");
    d.className = "err";
    d.textContent = e.message;
    out.append(d);
  }
}

function renderSqlResult(container, data) {
  container.innerHTML = "";
  if (!data.columns.length) {
    container.innerHTML = '<div class="empty">执行成功，无结果集</div>';
    return;
  }
  const wrap = document.createElement("div");
  wrap.className = "table-wrap";
  const table = document.createElement("table");

  const thead = document.createElement("thead");
  const trh = document.createElement("tr");
  const thNum = document.createElement("th");
  thNum.className = "rownum";
  thNum.textContent = "#";
  trh.append(thNum);
  data.columns.forEach(name => {
    const th = document.createElement("th");
    th.textContent = name;
    trh.append(th);
  });
  thead.append(trh);

  const tbody = document.createElement("tbody");
  data.rows.forEach((row, i) => {
    const tr = document.createElement("tr");
    const tdNum = document.createElement("td");
    tdNum.className = "rownum";
    tdNum.textContent = i + 1;
    tr.append(tdNum);
    row.forEach(v => {
      const td = document.createElement("td");
      if (v === null || v === undefined) {
        td.innerHTML = '<span class="null">NULL</span>';
      } else {
        const s = String(v);
        td.textContent = s.length > 200 ? s.slice(0, 200) + "…" : s;
        if (s.length > 200) td.title = s.slice(0, 1000);
      }
      tr.append(td);
    });
    tbody.append(tr);
  });

  table.append(thead, tbody);
  wrap.append(table);
  container.append(wrap);

  const info = document.createElement("div");
  info.className = "pager";
  info.textContent = `返回 ${data.rows.length} 行` + (data.rows.length === 1000 ? "（已截断至 1000 行）" : "");
  container.append(info);
}

$("#sql-run").onclick = runSql;
$("#sql-input").addEventListener("keydown", e => {
  if ((e.ctrlKey || e.metaKey) && e.key === "Enter") { e.preventDefault(); runSql(); }
});

/* ---------------- 启动 ---------------- */
init().catch(e => {
  document.body.innerHTML = '<pre style="padding:24px;color:#ff7b72">加载失败: ' + e.message + "</pre>";
});
</script>
</body>
</html>
"""


# ---------------------------------------------------------------- 入口

def main():
    global DB_PATH
    ap = argparse.ArgumentParser(description="SQLite 数据库查看器（零依赖）")
    ap.add_argument("database", help="SQLite 数据库文件路径")
    ap.add_argument("--host", default="127.0.0.1", help="监听地址（默认 127.0.0.1）")
    ap.add_argument("--port", type=int, default=8000, help="端口（默认 8000）")
    args = ap.parse_args()

    DB_PATH = os.path.abspath(args.database)
    if not os.path.exists(DB_PATH):
        print(f"错误: 数据库文件不存在: {DB_PATH}", file=sys.stderr)
        sys.exit(1)

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"SQLite 查看器已启动 → http://{args.host}:{args.port}")
    print(f"数据库: {DB_PATH}（只读模式打开）")
    print("按 Ctrl+C 停止")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()