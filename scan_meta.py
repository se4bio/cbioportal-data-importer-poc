#!/usr/bin/env python3

import sys
import os
import glob
import uuid

def sanitize_value(val):
    """Escape tabs and newlines in values for TSV safety."""
    return val.replace("\t", "\\t").replace("\n", "\\n")

def parse_meta_file(path):
    meta = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or ":" not in line:
                continue
            k, v = line.split(":", 1)
            meta[k.strip()] = sanitize_value(v.strip())
    return meta

def rel(path):
    return os.path.relpath(path, os.getcwd())

def scan_paths(paths):
    files = []
    for p in paths:
        # globs and file handling first
        if not os.path.isdir(p):
            for candidate in glob.glob(p):
                if os.path.isfile(candidate) and os.path.basename(candidate).startswith("meta_"):
                    files.append(candidate)
            continue

        # p is a directory -> add meta_* in that dir
        files.extend(glob.glob(os.path.join(p, "meta_*")))

        # check for case_lists
        case_list_dir = os.path.join(p, "case_lists")
        if os.path.isdir(case_list_dir):
            for entry in os.listdir(case_list_dir):
                full = os.path.join(case_list_dir, entry)
                if os.path.isfile(full):
                    files.append(full)

    return files

def main():
    args = sys.argv[1:]
    if not args:
        args = ["."]
    candidates = scan_paths(args)
    found_metas = [res for res in ((fpath, parse_meta_file(fpath)) for fpath in candidates) if res[1]]
    if not found_metas:
        print("No valid meta files found in", ",".join(args), "folder.", file=sys.stderr, flush=True)
        sys.exit(1)

    fixed_keys = [
        "cancer_study_identifier",
        "genetic_alteration_type",
        "datatype",
        "stable_id",
    ]

    # column order
    print("\t".join(["id", "meta_filepath", "data_filepath"] + fixed_keys + ["other"]))

    for fpath, meta in found_metas:
        meta_path_rel = rel(fpath)

        # resolve data_filename if present
        data_fname = meta.get("data_filename", "")
        if data_fname:
            data_path = os.path.join(os.path.dirname(fpath), data_fname)
            data_path_rel = rel(os.path.normpath(data_path))
        else:
            data_path_rel = ""

        # fixed keys in order
        row = [str(uuid.uuid4()), meta_path_rel, data_path_rel] + [meta.get(k, "") for k in fixed_keys]

        # other properties
        other = {k: v for k, v in meta.items() if k not in fixed_keys and k != "data_filename"}
        if other:
            other_str = "{" + ",".join([f"'{k}':'{v}'" for k, v in other.items()]) + "}"
        else:
            other_str = "{}"

        row.append(other_str)
        print("\t".join(row))


if __name__ == "__main__":
    main()

