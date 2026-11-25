#!/usr/bin/env python3
"""Machine-translate pipeline .json and .md files with LibreTranslate.

Text is split into segments (one markdown line, table cell or JSON label).
Things that must not be translated (glossary terms, code, URLs, links) are
replaced by tokens like X0, so each sentence is sent whole as plain text.
Each segment is cached by the hash of the masked text, so only new or
changed segments are translated. Output goes to .translation/<lang>/.

Env: LIBRETRANSLATE_API_KEY (required unless --dry-run), LIBRETRANSLATE_URL.
"""
import argparse
import copy
import hashlib
import html
import json
import os
import re
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path

import requests
import yaml

ROOT = Path(__file__).resolve().parents[2]
TR_DIR = ROOT / ".translation"
CONFIG = TR_DIR / "config.yml"
CACHE_NAME = "cache.json"
API_URL = os.environ.get("LIBRETRANSLATE_URL", "https://translate.geobon.org/translate")
BATCH_ITEMS = 20
BATCH_CHARS = 1000  # the server fails on larger requests
MAX_CHARS = 600  # longer segments are split by sentence

TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])X(\d+)(?![A-Za-z0-9])")  # allows X0_ in _italics_
CODE_RE = re.compile(r"`[^`\n]+`")
RAW_HTML_RE = re.compile(r"</?[A-Za-z!][^>\n]*>")
LINK_RE = re.compile(r"(!?)\[([^\]\n]*)\]\(([^)\n]+)\)")
URL_RE = re.compile(r"https?://[^\s<>()\[\]]+")
DOI_RE = re.compile(r"\bdoi:\s?10\.\S*[^\s.,;:)\]]", re.I)
# Quoted values without spaces are option names or identifiers: "near", 'chelsa-clim|bio1'.
QUOTED_RE = re.compile(r"\"[^\"\s]+\"|“[^”\s]+”|'[^'\s]+'")
UNDERSCORE_EM_RE = re.compile(r"(?<![\w*])_(?=\S)([^_\n]+?)(?<=\S)_(?!\w)")

# Lines listing people: only the label is translated, never the names.
NAMES_RE = re.compile(
    r"^([*_]*)(Author\(s\)|Authors?|Developers?|Project coordinators?|Contributors?|Maintainers?|Reviewed by)"
    r"([*_]*\s*:\s*)(.*?)([*_]*\s*)$", re.I)
REVIEW_STATUS_RE = re.compile(r"^(in review|reviewed|in development|under development|beta testing)$", re.I)
# Sections copied unchanged: reference lists are titles, names and DOIs.
REFERENCES_RE = re.compile(r"^[*_\s]*(references?|citations?|bibliography)[*_:\s]*$", re.I)

FENCE_RE = re.compile(r"^\s*(```|~~~)")
PREFIX_RE = re.compile(r"^(\s*(?:(?:#{1,6}|>|[-*+]|\d+[.)])\s+)*(?:\[[ xX]\]\s+)?)")
TABLE_SEP_RE = re.compile(r"^\s*\|?(\s*:?-+:?\s*\|)+\s*(:?-+:?\s*)?$")


class Glossary:
    def __init__(self, entries, lang):
        self.rules = []
        for e in sorted(entries, key=lambda e: -len(e["term"])):
            translations = e.get("translations")
            if translations is None:
                fixed = e["term"]  # keep the term as written in the glossary
            elif lang in translations:
                fixed = str(translations[lang])
            else:
                continue  # let LibreTranslate translate it
            term = re.escape(e["term"])
            self.rules.append((re.compile(rf"(?<!\w){term}(?!\w)", re.I), fixed))

    def apply(self, text, token):
        for pattern, fixed in self.rules:
            text = pattern.sub(lambda m, fixed=fixed: token(fixed, glossary=True), text)
        return text


def mask(text, glossary, translate_link_text):
    """Replace protected parts with tokens X0, X1, ...

    Returns (masked, values); each value is (text, is_glossary_term).
    """
    values = []

    def token(value, glossary=False):
        values.append((value, glossary))
        return f"X{len(values) - 1}"

    def link(m):
        bang, label, target = m.groups()
        return token(f"{bang}[{translate_link_text(label)}]({target})")

    t = TOKEN_RE.sub(lambda m: token(m.group(0)), text)  # literal "X1" in the source
    t = LINK_RE.sub(link, t)  # first, so code inside link text is handled by the nested call
    t = CODE_RE.sub(lambda m: token(m.group(0)), t)
    t = RAW_HTML_RE.sub(lambda m: token(m.group(0)), t)
    t = URL_RE.sub(lambda m: token(m.group(0)), t)
    t = DOI_RE.sub(lambda m: token(m.group(0)), t)
    t = QUOTED_RE.sub(lambda m: token(m.group(0)), t)
    t = UNDERSCORE_EM_RE.sub(r"*\1*", t)  # the model drops _ but keeps *
    return glossary.apply(t, token), values


# Text before a token that puts it at the start of a sentence.
SENTENCE_START_RE = re.compile(r"(?:^|[.!?][\"')\]]?\s+)[*_]*$")


def unmask(text, values):
    def restore(m):
        value, is_term = values[int(m.group(1))]
        # Glossary terms use the glossary's spelling, capitalised at sentence start.
        # Mixed-case names (openEO, habitatChange) are never changed.
        if is_term and value == value.lower() and SENTENCE_START_RE.search(text, 0, m.start()):
            value = value[:1].upper() + value[1:]
        return value

    text = clean_output(text)
    text = TOKEN_RE.sub(restore, text)
    # The model sometimes adds spaces inside **bold**, which breaks it.
    return re.sub(r"\*\*[ \t]*([^*\n]+?)[ \t]*\*\*", r"**\1**", text)


def clean_output(text):
    """Fix artefacts the model sometimes produces."""
    text = re.sub(r"& ?#(\d+);", lambda m: chr(int(m.group(1))), text).replace("\u00a0", " ")
    text = re.sub(r"(?<=\S) {2,}(?=\S)", " ", text)
    text = re.sub(r"(\w) ' (\w)", r"\1'\2", text)  # aujourd ' hui
    return re.sub(r"\b([cdjlmnst]|qu) ' ?(?=\w)", r"\1'", text, flags=re.I)  # l ' examen


def tokens_match(source, translated):
    return Counter(TOKEN_RE.findall(source)) == Counter(TOKEN_RE.findall(translated))


def has_text(masked):
    """True if anything translatable is left besides tokens."""
    return re.search(r"[^\W\d_]", TOKEN_RE.sub("", masked)) is not None


def split_long(masked, max_len=MAX_CHARS):
    """Split a long segment into chunks of whole sentences.

    The server fails on very long inputs.
    """
    if len(masked) <= max_len:
        return [masked]
    chunks = []
    for s in re.split(r"(?<=[.!?])\s+(?=\S)", masked):
        if chunks and len(chunks[-1]) + 1 + len(s) <= max_len:
            chunks[-1] += " " + s
        else:
            chunks.append(s)
    return chunks


def fmt_time(seconds):
    m, s = divmod(int(seconds), 60)
    return f"{m}m{s:02d}s" if m else f"{s}s"


class Translator:
    def __init__(self, source, lang, glossary, cache, api_key):
        self.source, self.lang, self.glossary = source, lang, glossary
        self.cache, self.api_key = cache, api_key
        self.missing = {}  # cache key -> masked text
        self.used = set()
        self.api_calls = 0
        self.fallbacks = 0

    def __call__(self, text):
        """Translate one segment, keeping its outer whitespace."""
        core = text.strip()
        if not core:
            return text
        lead = text[: len(text) - len(text.lstrip())]
        trail = text[len(text.rstrip()):]
        masked, values = mask(core, self.glossary, self)
        if not has_text(masked):
            return lead + unmask(masked, values) + trail
        chunks = split_long(masked)
        out = []
        for chunk in chunks:
            key = hashlib.sha256(chunk.encode()).hexdigest()
            self.used.add(key)
            if key in self.cache:
                out.append(self.cache[key])
            else:
                self.missing[key] = chunk
        if len(out) < len(chunks):
            return text  # not all chunks cached yet (first pass)
        return lead + unmask(" ".join(out), values) + trail

    def fetch(self):
        """Send missing segments in small batches (large requests time out)."""
        self.done, self.total, self.start = 0, len(self.missing), time.monotonic()
        batch, size = [], 0
        for item in list(self.missing.items()):
            if batch and (len(batch) >= BATCH_ITEMS or size + len(item[1]) > BATCH_CHARS):
                self._fetch_batch(batch)
                batch, size = [], 0
            batch.append(item)
            size += len(item[1])
        if batch:
            self._fetch_batch(batch)
        if self.total and sys.stdout.isatty():
            print()  # end the progress line
        self.missing.clear()

    def _progress(self, n):
        self.done += n
        elapsed = time.monotonic() - self.start
        left = elapsed / self.done * (self.total - self.done)
        msg = (f"[{self.lang}] {self.done}/{self.total} segments "
               f"({100 * self.done // self.total}%), {fmt_time(elapsed)} elapsed, ~{fmt_time(left)} left")
        if sys.stdout.isatty():
            print("\r" + msg.ljust(80), end="", flush=True)
        else:  # CI logs: one line per batch
            print(msg, flush=True)

    def _fetch_batch(self, batch):
        # Retry a failing batch as two halves; single items get full retries.
        out = self._call_api([p for _, p in batch], "text", attempts=5 if len(batch) == 1 else 2)
        if out is None:
            if len(batch) == 1:
                sys.exit("LibreTranslate: giving up after 5 attempts")
            mid = len(batch) // 2
            self._fetch_batch(batch[:mid])
            self._fetch_batch(batch[mid:])
            return
        for (key, masked), translated in zip(batch, out):
            if not tokens_match(masked, translated):
                translated = self._fallback(masked)
            self.cache[key] = translated
        self._progress(len(batch))

    def _fallback(self, masked):
        """Tokens got lost: retry with each token in a no-translate span."""
        self.fallbacks += 1
        protected = TOKEN_RE.sub(lambda m: f'<span translate="no">{m.group(0)}</span>',
                                 html.escape(masked, quote=False))
        out = self._call_api([protected], "html", attempts=5)
        if out is not None:
            translated = html.unescape(re.sub(r'<span translate="no">(.*?)</span>', r"\1", out[0]))
            if tokens_match(masked, translated):
                return translated
        # Last resort: one sentence at a time; only failing sentences stay English.
        sentences = re.split(r"(?<=[.!?])\s+(?=\S)", masked)
        if len(sentences) > 1:
            out = self._call_api(sentences, "text", attempts=3) or sentences
            parts = []
            for src, tgt in zip(sentences, out):
                if not tokens_match(src, tgt):
                    print(f"  WARNING: kept English, tokens lost: {src[:100]}", file=sys.stderr)
                    tgt = src
                parts.append(tgt)
            return " ".join(parts)
        print(f"  WARNING: kept English, tokens lost: {masked[:100]}", file=sys.stderr)
        return masked

    def _call_api(self, q, fmt, attempts):
        """Return the translations, or None if the request kept failing."""
        payload = {"q": q, "source": self.source, "target": self.lang,
                   "format": fmt, "api_key": self.api_key}
        for attempt in range(attempts):
            self.api_calls += 1
            try:
                r = requests.post(API_URL, json=payload, timeout=300)
            except requests.RequestException as e:
                err = str(e)
            else:
                if r.status_code == 200:
                    out = r.json().get("translatedText")
                    if isinstance(out, list) and len(out) == len(q):
                        return out
                    err = f"unexpected response: {r.text[:200]}"
                elif r.status_code in (429, 500, 502, 503, 504):
                    err = f"HTTP {r.status_code}"
                else:
                    sys.exit(f"LibreTranslate error HTTP {r.status_code}: {r.text[:500]}")
            if attempt + 1 < attempts:
                wait = 2 ** attempt * 5
                print(f"  API call failed ({err}), retrying in {wait}s", file=sys.stderr)
                time.sleep(wait)
        print(f"  API call failed ({err}) for {len(q)} segment(s)", file=sys.stderr)
        return None


def translate_table_row(line, tr):
    cells = re.split(r"(?<!\\)\|", line)
    return "|".join(tr(c) for c in cells)


def is_continuation(line, prev):
    """True if line continues the paragraph or list item on prev (hard wrap)."""
    s = line.strip()
    if not s or not prev.strip() or prev.endswith("  ") or prev.rstrip().endswith("\\"):
        return False
    if FENCE_RE.match(line) or s.startswith(("|", "<!--")) or PREFIX_RE.match(line).group(1).strip():
        return False
    if REFERENCES_RE.match(s) or NAMES_RE.match(s):
        return False
    return True


def translate_markdown(text, tr):
    lines = text.split("\n")
    out = []
    in_fence = in_comment = False
    skip_level = 0
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        i += 1
        if FENCE_RE.match(line):
            in_fence = not in_fence
            out.append(line)
        elif in_fence:
            out.append(line)
        elif in_comment or stripped.startswith("<!--"):
            in_comment = "-->" not in line
            out.append(line)
        elif stripped.startswith("|"):
            out.append(line if TABLE_SEP_RE.match(line) else translate_table_row(line, tr))
        else:
            prefix = PREFIX_RE.match(line).group(1)
            body = line[len(prefix):]
            level = len(prefix.strip()) if prefix.lstrip().startswith("#") else 0
            if skip_level and (0 < level <= skip_level or (skip_level == 7 and level)):
                skip_level = 0  # a heading closes the references section
            if skip_level:
                out.append(line)
                continue
            if REFERENCES_RE.match(body):
                skip_level = level or 7  # bold-line title: skip until the next heading
                out.append(prefix + tr(body))
                continue
            names = NAMES_RE.match(body)
            if names:
                lead, label, sep, value, end = names.groups()
                if REVIEW_STATUS_RE.match(value):
                    value = tr(value)
                out.append(prefix + lead + tr(label) + sep + value + end)
                continue
            if not level:
                # Join wrapped lines so a sentence is translated as one segment.
                while i < len(lines) and is_continuation(lines[i], lines[i - 1]):
                    body = body.rstrip() + " " + lines[i].strip()
                    i += 1
            out.append(prefix + tr(body))
    return "\n".join(out)


def translate_pipeline(data, tr):
    """Full copy of a pipeline with its user-facing text translated."""
    d = copy.deepcopy(data)
    meta = d.get("metadata") or {}
    if isinstance(meta.get("name"), str):
        meta["name"] = tr(meta["name"])
    if isinstance(meta.get("description"), str):
        meta["description"] = translate_markdown(meta["description"], tr)
    for section in ("inputs", "outputs"):
        for item in (d.get(section) or {}).values():
            if isinstance(item.get("label"), str):
                item["label"] = tr(item["label"])
            if isinstance(item.get("description"), str):
                item["description"] = translate_markdown(item["description"], tr)
    return d


def render(rel, tr):
    text = (ROOT / rel).read_text(encoding="utf-8")
    if rel.suffix == ".json":
        data = translate_pipeline(json.loads(text), tr)
        return json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    return translate_markdown(text, tr)


def source_files(patterns):
    """Files matching the include patterns, minus git-ignored ones."""
    found = {p.relative_to(ROOT) for pat in patterns for p in ROOT.glob(pat) if p.is_file()}
    try:
        listed = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
            cwd=ROOT, capture_output=True, check=True).stdout.decode().split("\0")
        found &= {Path(p) for p in listed if p}
    except (OSError, subprocess.CalledProcessError):
        pass
    return sorted(found)


def remove_orphans(lang_dir, sources):
    removed = 0
    for p in sorted(lang_dir.rglob("*"), reverse=True):
        if p.is_file() and p.name != CACHE_NAME and p.relative_to(lang_dir) not in sources:
            p.unlink()
            removed += 1
        elif p.is_dir() and not any(p.iterdir()):
            p.rmdir()
    return removed


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", action="append", help="target language (default: all in config)")
    ap.add_argument("--files", nargs="+", help="only these source files (no cache cleanup)")
    ap.add_argument("--dry-run", action="store_true", help="report what would be sent, write nothing")
    args = ap.parse_args()

    cfg = yaml.safe_load(CONFIG.read_text(encoding="utf-8"))
    source_lang = cfg.get("source", "en")
    sources = source_files(cfg["include"])
    if args.files:
        targets = [Path(os.path.relpath(Path(f).resolve(), ROOT)) for f in args.files]
        unknown = [str(t) for t in targets if t not in sources]
        if unknown:
            sys.exit(f"Not a translatable source file: {', '.join(unknown)}")
    else:
        targets = sources

    api_key = os.environ.get("LIBRETRANSLATE_API_KEY", "")
    if not api_key and not args.dry_run:
        sys.exit("LIBRETRANSLATE_API_KEY is not set")

    for lang in args.lang or cfg["languages"]:
        lang_dir = TR_DIR / lang
        cache_path = lang_dir / CACHE_NAME
        cache = json.loads(cache_path.read_text(encoding="utf-8")) if cache_path.exists() else {}
        tr = Translator(source_lang, lang, Glossary(cfg.get("glossary") or [], lang), cache, api_key)

        for rel in targets:  # first pass: find segments missing from the cache
            render(rel, tr)
        to_send = len(tr.missing)
        print(f"[{lang}] {len(targets)} files, {len(tr.used)} segments, {to_send} to translate")
        if args.dry_run:
            for p in tr.missing.values():
                print(f"  + {p}")
            continue
        try:
            tr.fetch()
        finally:  # keep finished translations even if the run fails
            lang_dir.mkdir(parents=True, exist_ok=True)
            cache_path.write_text(json.dumps(cache, indent=1, ensure_ascii=False, sort_keys=True) + "\n",
                                  encoding="utf-8")

        written = 0
        for rel in targets:
            out_path = lang_dir / rel
            content = render(rel, tr)
            if not out_path.exists() or out_path.read_text(encoding="utf-8") != content:
                out_path.parent.mkdir(parents=True, exist_ok=True)
                out_path.write_text(content, encoding="utf-8")
                written += 1

        removed = 0
        if not args.files:  # full run: drop unused cache entries and orphan files
            cache = {k: v for k, v in cache.items() if k in tr.used}
            removed = remove_orphans(lang_dir, set(sources))
        lang_dir.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(cache, indent=1, ensure_ascii=False, sort_keys=True) + "\n",
                              encoding="utf-8")
        print(f"[{lang}] {tr.api_calls} API calls, {tr.fallbacks} fallbacks, "
              f"{written} files written, {removed} removed")


if __name__ == "__main__":
    main()
