#!/usr/bin/env node
/**
 * scan.js — what the payload does on a machine, compared with what SAFETY.md says it does.
 *
 *   node test/safety/scan.js <template-dir> <page>        exit 0 when they match, 1 when not
 *   node test/safety/scan.js <template-dir> --list        print what was found, one per line
 *
 * Part of the workflow's own repository (test/ is never copied into a project). It finds five kinds of thing in the payload's code:
 *   hook     a file in .githooks/ — it runs on every commit
 *   network  a call that reaches another machine: fetch(), http(s).request, curl, wget, …
 *   import   a module that is not built into Node (a dependency someone must install)
 *   program  a program a script runs (git, awk, …), from shell and from child_process
 *   home     a file that reads or writes under the user's home directory, outside the repo
 * and compares them with the allow-list table in the page, between the SAFETY:ALLOW markers.
 * The page is the only list: this script carries none (one source, referenced).
 *
 * It reads code, never docs: Markdown is skipped, and comments are removed before matching,
 * so a URL in a comment or a README is not a call. Shell is not parsed, only tokenised: a
 * command is the first word after a line start or an operator, once quoted text and heredoc
 * bodies are removed. That errs toward reporting too much, which the page then has to explain;
 * a scanner that goes quiet on a real call is the failure it exists to prevent.
 */
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { builtinModules } = require("node:module");

const BUILTINS = new Set(builtinModules.flatMap((m) => [m, `node:${m}`]));

// Shell words that are not programs: keywords and builtins (bash and POSIX sh).
const SHELL_WORDS = new Set(
  ("if then else elif fi for while until do done case esac in function select time " +
    "cd echo printf read set shift local return exit export trap test true false eval source " +
    "shopt declare typeset unset wait break continue type hash getopts umask let readonly alias " +
    "mapfile readarray pushd popd dirs exec command builtin enable caller compgen complete " +
    "disown jobs kill fg bg suspend logout history fc ulimit times pwd").split(/\s+/)
);
// A wrapper runs the word after it; that word is the program.
const WRAPPERS = new Set(["command", "exec", "xargs", "env", "nohup", "timeout", "sudo", "nice", "time"]);

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

function kindOf(file) {
  if (/\.(md|txt|json|ya?ml|dbml|example)$/i.test(file) || path.basename(file).startsWith(".env")) return null;
  if (/\.(c|m)?js$/.test(file)) return "js";
  const head = fs.readFileSync(file, "utf8").slice(0, 120);
  if (/\.sh$/.test(file) || /^#!.*\b(ba)?sh\b/.test(head)) return "sh";
  if (/^#!.*\bnode\b/.test(head)) return "js";
  return null;
}

// --- JavaScript -------------------------------------------------------------------------------

function stripJsComments(src) {
  // Strings are kept (a URL in a string is data the call may use); comments are dropped.
  let out = "", i = 0, q = null;
  while (i < src.length) {
    const c = src[i], n = src[i + 1];
    if (q) {
      out += c;
      if (c === "\\") { out += n || ""; i += 2; continue; }
      if (c === q) q = null;
      i++;
      continue;
    }
    if (c === "'" || c === '"' || c === "`") { q = c; out += c; i++; continue; }
    if (c === "/" && n === "/") { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (c === "/" && n === "*") { const e = src.indexOf("*/", i + 2); i = e < 0 ? src.length : e + 2; continue; }
    out += c;
    i++;
  }
  return out;
}

function scanJs(code, add) {
  for (const m of code.matchAll(/\brequire\(\s*['"]([^'"]+)['"]\s*\)|\bimport\b[^'"]*?\bfrom\s*['"]([^'"]+)['"]|\bimport\(\s*['"]([^'"]+)['"]\s*\)/g)) {
    const mod = m[1] || m[2] || m[3];
    if (!mod.startsWith(".") && !mod.startsWith("/") && !BUILTINS.has(mod)) add("import", mod);
  }
  for (const m of code.matchAll(/\bfetch\(\s*([^,)]*)/g)) add("network", destination(m[1]));
  for (const m of code.matchAll(/\b(?:https?|net|tls|dgram|http2)\.(?:request|get|connect|createConnection)\(\s*([^,)]*)/g))
    add("network", destination(m[1]));
  if (/\bnew\s+(?:WebSocket|XMLHttpRequest)\b/.test(code)) add("network", "(socket)");
  for (const m of code.matchAll(/\b(?:execFileSync|execFile|spawnSync|spawn|fork)\(\s*([^,)]*)/g))
    add("program", programOf(m[1], code, m.index + m[0].length));
  for (const m of code.matchAll(/\b(?:execSync|exec)\(\s*(['"`])([^'"`\s]+)/g)) add("program", m[2]);
  if (/\bhomedir\(\)|process\.env\.HOME\b/.test(code)) add("home", null);
}

function destination(arg) {
  const lit = arg.trim().match(/^['"`](https?:\/\/[^/'"`$]+)/);
  return lit ? new URL(lit[1]).host : "(configured)";
}
// `at` is where the first argument ends in `code`. Running Node itself is plain `node` only when
// the script it runs is fixed: a literal, or a file beside this one. A script found
// through a setting is configured code, whichever interpreter runs it.
function programOf(arg, code, at) {
  if (arg.trim() === "process.execPath") return fixedScript(firstElement(code, at), code) ? "node" : "(configured)";
  const lit = arg.trim().match(/^['"`]([^'"`]+)['"`]$/);
  return lit ? lit[1] : "(configured)";
}
// The first element of the args array after `at` (", [ <this>, …"), or null when there is none.
function firstElement(code, at) {
  const open = code.slice(at).match(/^\s*,\s*\[\s*/);
  if (!open) return null;
  let i = at + open[0].length, depth = 0, q = null;
  const start = i;
  for (; i < code.length; i++) {
    const c = code[i];
    if (q) { if (c === "\\") i++; else if (c === q) q = null; continue; }
    if (c === "'" || c === '"' || c === "`") q = c;
    else if ("([{".includes(c)) depth++;
    else if (")]}".includes(c)) { if (depth-- === 0) break; }
    else if (c === "," && depth === 0) break;
  }
  return code.slice(start, i).trim();
}
const BESIDE = /^path\.(?:join|resolve)\(\s*(?:__dirname|HERE)\s*,\s*(['"])[^'"`$]+\1\s*\)$/;
function fixedScript(el, code) {
  if (!el) return false;
  if (/^(['"])[^'"]*\1$/.test(el)) return true; // a literal: a flag such as -e, or a fixed path
  if (BESIDE.test(el)) return true;
  if (!/^[A-Za-z_$][\w$]*$/.test(el)) return false;
  // A name counts only when every binding of it in the file is a file beside this one.
  const binds = [...code.matchAll(new RegExp(`\\b(?:const|let|var)\\s+${el.replace(/\$/g, "\\$")}\\s*=\\s*([^;\\n]+)`, "g"))];
  return binds.length > 0 && binds.every((b) => BESIDE.test(b[1].trim()));
}

// --- Shell ------------------------------------------------------------------------------------

// Heredoc bodies are data (their opening line still runs: `node <<'EOF'` runs node). Returns the
// script with each body removed, and the bodies, which may hold another interpreter's program.
function dropHeredocs(src, raw) {
  const lines = src.split("\n"), kept = [];
  for (let i = 0; i < lines.length; i++) {
    if (i === 0 && lines[i].startsWith("#!")) continue;
    kept.push(lines[i]);
    const hd = lines[i].match(/<<-?\s*(['"]?)([A-Za-z_]\w*)\1/);
    if (!hd || /<<</.test(lines[i])) continue;
    const body = [];
    while (++i < lines.length && lines[i].trim() !== hd[2]) body.push(lines[i]);
    raw.push(body.join("\n"));
  }
  return kept.join("\n");
}

// Over the whole script, since quotes span lines: single-quoted text becomes '' and double-quoted
// text "" — but a command substitution inside double quotes still runs, so its text is kept and
// scanned on its own. Comments are dropped. The quoted text itself goes to `raw`, where an inline
// program for another interpreter (node -e '…fetch(…)…') is still checked for network calls.
// text[i] is the "(" of "$(": the index of its matching ")", skipping quoted text inside it.
function matchParen(text, i) {
  let depth = 1, j = i + 1;
  while (j < text.length) {
    const c = text[j];
    if (c === "\\") { j += 2; continue; }
    if (c === "'") { const e = text.indexOf("'", j + 1); j = e < 0 ? text.length : e + 1; continue; }
    if (c === '"') { j = skipDouble(text, j) + 1; continue; }
    if (c === "(") depth++;
    else if (c === ")" && --depth === 0) return j;
    j++;
  }
  return text.length;
}
// text[i] is an opening '"': the index of its closing one. A "$(…)" inside may hold quotes of its own.
function skipDouble(text, i) {
  let j = i + 1;
  while (j < text.length && text[j] !== '"') {
    if (text[j] === "\\") j += 2;
    else if (text[j] === "$" && text[j + 1] === "(") j = matchParen(text, j + 1) + 1;
    else j++;
  }
  return j;
}

function unquote(text, extra, raw) {
  let out = "", i = 0;
  while (i < text.length) {
    const c = text[i];
    if (c === "\\") { out += text.slice(i, i + 2); i += 2; continue; }
    if (c === "'") {
      const e = text.indexOf("'", i + 1), end = e < 0 ? text.length : e;
      raw.push(text.slice(i + 1, end)); out += "''"; i = end + 1; continue;
    }
    if (c === '"') {
      const end = skipDouble(text, i), inner = text.slice(i + 1, end);
      for (let k = 0; k < inner.length; k++) {
        if (inner[k] === "\\") { k++; continue; }
        if (inner[k] === "$" && inner[k + 1] === "(") { const e = matchParen(inner, k + 1); extra.push(inner.slice(k + 2, e)); k = e; }
        else if (inner[k] === "`") { const e = inner.indexOf("`", k + 1); if (e > 0) { extra.push(inner.slice(k + 1, e)); k = e; } }
      }
      raw.push(inner); out += '""'; i = end + 1; continue;
    }
    if (c === "#" && (i === 0 || /[\s;|&(]/.test(text[i - 1]))) { while (i < text.length && text[i] !== "\n") i++; continue; }
    out += c; i++;
  }
  return out;
}

function commandWords(code, add, funcs) {
  // Arithmetic is not a command, but a command substitution inside it still runs:
  // `$(( n + $(wc -l < f) ))` keeps `wc -l < f` as a segment of its own.
  code = code.replace(/\$?\(\([\s\S]*?\)\)/g, (m) => " " + [...m.matchAll(/\$\(([^()]*)\)/g)].map((x) => `\n${x[1]}\n`).join(""));
  // A case pattern (`a|b/*)`) at the start of a line is not a command, and its `|` is not a pipe.
  code = code.replace(/^(\s*\(?)[^\s();|&]+(?:\s*\|\s*[^\s();|&]+)*\)(?=\s|$)/gm, "$1");
  for (const seg of code.split(/\|\||&&|[;|&{}`\n]|\$\(|\b(?:then|do|else|elif|if|while|until|time|!)\s/)) {
    const words = seg.trim().split(/\s+/).map((w) => w.replace(/^\(+/, "")).filter(Boolean);
    if (words.length && /\)$/.test(words[0])) words.shift(); // a case pattern, or `name()`
    while (words.length && (/^[A-Za-z_]\w*(\[[^\]]*\])?\+?=/.test(words[0]) || /^\d*[<>]/.test(words[0]))) words.shift();
    let w = words[0];
    if (!w) continue;
    if (WRAPPERS.has(w)) {
      if (w !== "command" && w !== "exec" && w !== "time") add("program", w);
      w = words.find((x, k) => k > 0 && !x.startsWith("-") && !/^[A-Za-z_]\w*=/.test(x) && !/^-[uCS]$/.test(words[k - 1]));
      if (!w) continue;
    }
    w = w.replace(/^\\/, "").replace(/\)+$/, "");
    if (/^["$]/.test(w)) { add("program", "(configured)"); continue; } // a program named by a variable
    if (!/^[A-Za-z][\w.+-]*$/.test(w) || SHELL_WORDS.has(w) || funcs.has(w)) continue;
    add("program", w);
    if (/^(curl|wget|nc|ncat|ssh|scp|sftp|rsync|ftp|telnet)$/.test(w)) add("network", `(${w})`);
  }
}

const FUNC_DEF = /(?:^|[;&|{])\s*(?:function\s+)?([A-Za-z_][\w-]*)\s*\(\)/gm;
// `. "<dir>/<name>.sh"` (or `source …`): the functions that payload file defines are not programs.
const SOURCED = /(?:^|[;&|{]|\bthen|\bdo)\s*(?:\.|source)\s+["']?[^"'\s;]*?([\w.-]+\.sh)["']?/gm;

function scanShell(src, add, raw, shFuncs = new Map()) {
  const funcs = new Set([...src.matchAll(FUNC_DEF)].map((m) => m[1]));
  for (const m of src.matchAll(SOURCED)) for (const f of shFuncs.get(m[1]) ?? []) funcs.add(f);
  const extra = [];
  const code = unquote(dropHeredocs(src, raw).replace(/\\\n/g, " "), extra, raw);
  commandWords(code, add, funcs);
  for (let k = 0; k < extra.length; k++) commandWords(unquote(extra[k], extra, raw), add, funcs);
  if (/\$\{?HOME\b|(^|[\s=:])~\//.test(code) || raw.some((t) => /\$\{?HOME\b/.test(t))) add("home", null);
}

// --- Compare with the page --------------------------------------------------------------------

function findings(templateDir) {
  const found = new Map(); // "kind\titem" → Set(files)
  const put = (kind, item, file) => {
    const key = `${kind}\t${item}`;
    if (!found.has(key)) found.set(key, new Set());
    found.get(key).add(file);
  };
  const files = walk(templateDir).sort();
  // Functions each payload shell file defines, by file name, for the scripts that source it.
  const shFuncs = new Map();
  for (const abs of files) if (abs.endsWith(".sh")) {
    const names = [...fs.readFileSync(abs, "utf8").matchAll(FUNC_DEF)].map((m) => m[1]);
    shFuncs.set(path.basename(abs), [...(shFuncs.get(path.basename(abs)) ?? []), ...names]);
  }
  for (const abs of files) {
    const rel = path.relative(templateDir, abs).split(path.sep).join("/");
    if (rel.startsWith(".githooks/")) put("hook", path.basename(rel), rel);
    const kind = kindOf(abs);
    if (!kind) continue;
    const src = fs.readFileSync(abs, "utf8");
    // A configured program or destination is named by its file, so a new one anywhere is new.
    const add = (k, item) => put(k, item === null ? rel : item === "(configured)" ? `(configured) ${rel}` : item, rel);
    if (kind === "js") scanJs(stripJsComments(src), add);
    else {
      const raw = [];
      scanShell(src, add, raw, shFuncs);
      // Inline programs for another interpreter (node -e, a heredoc fed to node) are JavaScript.
      for (const t of raw) scanJs(t, (k, item) => k !== "program" && k !== "home" && add(k, item));
    }
  }
  return found;
}

function allowList(page) {
  const text = fs.readFileSync(page, "utf8");
  const m = text.match(/<!-- SAFETY:ALLOW START -->([\s\S]*?)<!-- SAFETY:ALLOW END -->/);
  if (!m) throw new Error(`${page}: no <!-- SAFETY:ALLOW START --> … <!-- SAFETY:ALLOW END --> block`);
  const keys = new Set();
  for (const line of m[1].split("\n")) {
    const cells = line.split("|").map((c) => c.trim());
    if (cells.length < 4 || /^-+$/.test(cells[1]) || cells[1].toLowerCase() === "kind") continue;
    keys.add(`${cells[1].replace(/`/g, "")}\t${cells[2].replace(/`/g, "")}`);
  }
  return keys;
}

function main(argv) {
  const [templateDir, page] = argv;
  if (!templateDir || !page) {
    console.error("usage: scan.js <template-dir> <page> | --list");
    return 2;
  }
  const found = findings(templateDir);
  if (page === "--list") {
    for (const [k, files] of [...found].sort()) console.log(`${k}\t${[...files].join(", ")}`);
    return 0;
  }
  const allowed = allowList(page);
  const unlisted = [...found.keys()].filter((k) => !allowed.has(k)).sort();
  const stale = [...allowed].filter((k) => !found.has(k)).sort();
  for (const k of unlisted) console.log(`UNLISTED  ${k.replace("\t", "  ")}   (in ${[...found.get(k)].join(", ")})`);
  for (const k of stale) console.log(`STALE     ${k.replace("\t", "  ")}   (listed on the page, not found in the payload)`);
  if (unlisted.length || stale.length) {
    console.log(`✖ ${unlisted.length} unlisted, ${stale.length} stale — update ${page} and the code together.`);
    return 1;
  }
  console.log(`✔ ${found.size} item(s), every one listed on ${page}`);
  return 0;
}

if (require.main === module) process.exit(main(process.argv.slice(2)));
module.exports = { findings, allowList };
