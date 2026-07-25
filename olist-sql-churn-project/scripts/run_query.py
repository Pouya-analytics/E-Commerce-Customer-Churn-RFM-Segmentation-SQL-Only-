"""
run_query.py
Small helper to execute a .sql file against data/ecommerce.db and print
results as a readable table. Used to generate the verified sample output
shown in README.md -- every number in the README comes from an actual
execution of this script, not from hand-written examples.
"""
import sqlite3
import sys
import os

def run(sql_path, limit=None):
    db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "ecommerce.db")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    with open(sql_path) as f:
        sql = f.read()
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    if limit:
        rows = rows[:limit]

    widths = [max(len(str(c)), *(len(str(r[i])) for r in rows)) if rows else len(str(c))
              for i, c in enumerate(cols)]
    header = " | ".join(c.ljust(widths[i]) for i, c in enumerate(cols))
    print(header)
    print("-" * len(header))
    for r in rows:
        print(" | ".join(str(r[i]).ljust(widths[i]) for i in range(len(cols))))
    print(f"\n({len(rows)} rows shown)")
    conn.close()

if __name__ == "__main__":
    sql_file = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else None
    run(sql_file, limit)
