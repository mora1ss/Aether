#!/usr/bin/env python3
import json
import os
import select
import sys

LIMIT = 40
SKIP_DIRS = {"node_modules", ".git", ".cache", "target", "build", ".local"}


def search(query):
    home = os.path.expanduser("~")
    results = []
    query = query or ""

    if query.startswith("/") or query.startswith("~"):
        path = os.path.expanduser(query)
        ends_dir = query.endswith("/") or query.endswith("\\")
        directory = path if (os.path.isdir(path) and ends_dir) else (os.path.dirname(path) or home)
        prefix = "" if (os.path.isdir(path) and ends_dir) else os.path.basename(path).lower()
        if os.path.isdir(directory):
            try:
                entries = sorted(
                    os.listdir(directory),
                    key=lambda name: (not os.path.isdir(os.path.join(directory, name)), name.lower()),
                )
                for item in entries:
                    if item.startswith(".") and not prefix.startswith("."):
                        continue
                    if not prefix or prefix in item.lower():
                        full = os.path.join(directory, item)
                        results.append({"name": item, "path": full, "isDir": os.path.isdir(full)})
                        if len(results) >= LIMIT:
                            break
            except OSError:
                pass
        return results[:LIMIT]

    needle = query.lower().strip()
    targets = [
        home,
        os.path.join(home, "Desktop"),
        os.path.join(home, "Documents"),
        os.path.join(home, "Downloads"),
        os.path.join(home, "Pictures"),
        os.path.join(home, "Videos"),
        os.path.join(home, "Music"),
    ]
    seen = set()
    for target in targets:
        if not os.path.isdir(target):
            continue
        try:
            for root, dirs, files in os.walk(target):
                relative = os.path.relpath(root, target)
                if relative != "." and relative.count(os.sep) >= 2:
                    dirs.clear()
                    continue
                dirs[:] = [name for name in dirs if not name.startswith(".") and name not in SKIP_DIRS]
                if needle:
                    for directory in dirs:
                        if needle in directory.lower():
                            full = os.path.join(root, directory)
                            if full not in seen:
                                seen.add(full)
                                results.append({"name": directory, "path": full, "isDir": True})
                                if len(results) >= LIMIT:
                                    return results
                for filename in files:
                    if filename.startswith("."):
                        continue
                    if not needle or needle in filename.lower():
                        full = os.path.join(root, filename)
                        if full not in seen:
                            seen.add(full)
                            results.append({"name": filename, "path": full, "isDir": False})
                            if len(results) >= LIMIT:
                                return results
                if len(results) >= LIMIT:
                    return results
        except OSError:
            pass
        if len(results) >= LIMIT:
            break
    return results[:LIMIT]


def latest_pending(current):
    while True:
        ready, _, _ = select.select([sys.stdin], [], [], 0)
        if not ready:
            return current
        extra = sys.stdin.readline()
        if extra == "":
            return current
        current = extra
    return current


def main():
    while True:
        line = sys.stdin.readline()
        if line == "":
            break
        line = latest_pending(line)
        print(json.dumps(search(line.rstrip("\n"))), flush=True)


if __name__ == "__main__":
    main()
