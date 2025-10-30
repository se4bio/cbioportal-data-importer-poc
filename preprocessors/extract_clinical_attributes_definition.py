#!/usr/bin/env python3
import sys

def main():
    if len(sys.argv) < 3:
        sys.stderr.write("Usage: extract_clinical_attributes_definition.py <input_file> <stage_meta_id>\n")
        sys.exit(1)

    path = sys.argv[1]
    stage_meta_id = sys.argv[2]

    try:
        with open(path, "r", encoding="utf-8") as f:
            lines = [f.readline().rstrip("\n") for _ in range(5)]
    except Exception as e:
        sys.stderr.write(f"ERROR: Could not read file '{path}': {e}\n")
        sys.exit(2)

    if any(line == "" for line in lines):
        sys.stderr.write("ERROR: File does not contain at least 5 lines.\n")
        sys.exit(3)

    # First 4 are commented (#...), 5th is the actual header
    names_line    = lines[0].lstrip('#').strip()
    descr_line    = lines[1].lstrip('#').strip()
    types_line    = lines[2].lstrip('#').strip()
    priority_line = lines[3].lstrip('#').strip()
    header_line   = lines[4].strip()

    names     = names_line.split('\t')
    descrs    = descr_line.split('\t')
    types     = types_line.split('\t')
    priority  = priority_line.split('\t')
    headers   = header_line.split('\t')

    # Validate column count
    n = len(headers)
    if not (len(names) == len(descrs) == len(types) == len(priority) == n):
        sys.stderr.write("ERROR: Column count mismatch in metadata rows.\n")
        sys.exit(4)

    # Output
    print("attribute\tname\tdescription\ttype\tpriority\tstage_meta_id")
    for i in range(n):
        if headers[i] in {'PATIENT_ID', 'SAMPLE_ID'}:
            continue
        print(f"{headers[i]}\t{names[i]}\t{descrs[i]}\t{types[i]}\t{priority[i]}\t{stage_meta_id}")

if __name__ == "__main__":
    main()

