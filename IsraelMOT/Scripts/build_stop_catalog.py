#!/usr/bin/env python3
"""
build_stop_catalog.py
Deterministic nationwide stop catalog builder for OneBusAway Israel.

Reads official GTFS stops.txt (or KavNav JSON), validates Israeli geographic
boundaries, parses names and platforms, and creates an optimized SQLite database
with an R-Tree spatial index for instant viewport/bounding-box queries.
"""

import sys
import os
import csv
import sqlite3
import hashlib
import time
import re
from datetime import datetime, timezone

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Israel bounding box for sanity checks
ISRAEL_MIN_LAT = 29.4
ISRAEL_MAX_LAT = 33.5
ISRAEL_MIN_LON = 34.1
ISRAEL_MAX_LON = 35.9

def parse_desc(desc):
    """Parses standard MOT stop_desc like: 'רחוב: אבא הלל סילבר 17 עיר: ירושלים רציף:  קומה: '"""
    if not desc:
        return None, None, None
    street = None
    city = None
    platform = None
    
    m_street = re.search(r'רחוב:\s*([^:]+?)(?=\s*עיר:|$)', desc)
    if m_street:
        street = m_street.group(1).strip()
    
    m_city = re.search(r'עיר:\s*([^:]+?)(?=\s*רציף:|$)', desc)
    if m_city:
        city = m_city.group(1).strip()
        
    m_plat = re.search(r'רציף:\s*([^:]+?)(?=\s*קומה:|$)', desc)
    if m_plat:
        platform = m_plat.group(1).strip()
        
    return street, city, platform

def load_translations(translations_path):
    translations = {}
    if not translations_path or not os.path.exists(translations_path):
        print(f"[-] Translations file not found: {translations_path}, proceeding without translations.")
        return translations
    print(f"[*] Ingesting official MOT translations from: {translations_path}")
    with open(translations_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            tid = row.get('trans_id', '').strip()
            lang = row.get('lang', '').strip().upper()
            trans = row.get('translation', '').strip()
            if tid and lang and trans:
                if tid not in translations:
                    translations[tid] = {}
                translations[tid][lang] = trans
    print(f"[*] Loaded translations for {len(translations)} unique trans_ids")
    return translations

def build_catalog(stops_csv_path, output_sqlite_path, translations_path=None, dataset_version="2026-10-18"):
    print(f"[*] Reading GTFS stops from: {stops_csv_path}")
    start_time = time.time()
    
    if not os.path.exists(stops_csv_path):
        raise FileNotFoundError(f"Source file not found: {stops_csv_path}")
        
    translations = load_translations(translations_path)

    # Remove existing db if present
    if os.path.exists(output_sqlite_path):
        os.remove(output_sqlite_path)
        
    os.makedirs(os.path.dirname(os.path.abspath(output_sqlite_path)), exist_ok=True)
    
    conn = sqlite3.connect(output_sqlite_path)
    cur = conn.cursor()
    
    # Enable WAL mode and synchronous normal for build performance
    cur.execute("PRAGMA journal_mode = MEMORY;")
    cur.execute("PRAGMA synchronous = OFF;")
    
    # 1. Create tables
    cur.execute("""
    CREATE TABLE stops (
        stop_id INTEGER PRIMARY KEY,
        stop_code INTEGER NOT NULL,
        name_he TEXT NOT NULL,
        name_en TEXT,
        name_ar TEXT,
        street TEXT,
        city TEXT,
        platform_code TEXT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        location_type INTEGER DEFAULT 0,
        parent_station INTEGER
    );
    """)
    
    cur.execute("CREATE INDEX idx_stops_code ON stops (stop_code);")
    cur.execute("CREATE INDEX idx_stops_city ON stops (city);")
    
    # 2. Create SQLite R-Tree virtual table
    cur.execute("""
    CREATE VIRTUAL TABLE stops_rtree USING rtree(
        id,              -- Matches stops.stop_id
        min_lat, max_lat,
        min_lon, max_lon
    );
    """)
    
    cur.execute("""
    CREATE TABLE catalog_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
    );
    """)
    
    # 3. Read and insert rows
    hasher = hashlib.sha256()
    total_read = 0
    total_inserted = 0
    skipped_bounds = 0
    en_count = 0
    ar_count = 0
    
    stop_rows = []
    rtree_rows = []
    
    with open(stops_csv_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            total_read += 1
            raw_id = row.get('stop_id') or row.get('stopId')
            raw_code = row.get('stop_code') or row.get('stopCode')
            name_he = (row.get('stop_name') or row.get('stopName') or '').strip()
            desc = row.get('stop_desc') or row.get('stopDesc') or ''
            raw_lat = row.get('stop_lat') or row.get('lat')
            raw_lon = row.get('stop_lon') or row.get('lon')
            loc_type = int(row.get('location_type') or 0)
            parent_raw = row.get('parent_station') or row.get('parentStation')
            parent_station = int(parent_raw) if parent_raw and parent_raw.isdigit() else None
            
            try:
                stop_id = int(raw_id)
                stop_code = int(raw_code) if raw_code and raw_code.isdigit() else stop_id
                lat = float(raw_lat)
                lon = float(raw_lon)
            except (ValueError, TypeError):
                continue
                
            # Geo bounds check
            if not (ISRAEL_MIN_LAT <= lat <= ISRAEL_MAX_LAT and ISRAEL_MIN_LON <= lon <= ISRAEL_MAX_LON):
                skipped_bounds += 1
                continue
                
            street, city, platform = parse_desc(desc)
            
            t = translations.get(name_he, {})
            name_en = t.get('EN')
            name_ar = t.get('AR')
            if name_en: en_count += 1
            if name_ar: ar_count += 1
            
            stop_rows.append((
                stop_id, stop_code, name_he, name_en, name_ar,
                street, city, platform, lat, lon, loc_type, parent_station
            ))
            rtree_rows.append((
                stop_id, lat, lat, lon, lon
            ))
            
            hasher.update(f"{stop_id}:{stop_code}:{lat:.6f}:{lon:.6f}".encode('utf-8'))
            total_inserted += 1
            
    cur.executemany("""
    INSERT INTO stops (
        stop_id, stop_code, name_he, name_en, name_ar,
        street, city, platform_code, lat, lon, location_type, parent_station
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, stop_rows)
    
    cur.executemany("""
    INSERT INTO stops_rtree (id, min_lat, max_lat, min_lon, max_lon)
    VALUES (?, ?, ?, ?, ?);
    """, rtree_rows)
    
    # 4. Insert metadata
    checksum = hasher.hexdigest()
    now_iso = datetime.now(timezone.utc).isoformat()
    metadata = [
        ("source", "GTFS-MOT"),
        ("dataset_version", dataset_version),
        ("schema_version", "1.1"),
        ("record_count", str(total_inserted)),
        ("translations_en_count", str(en_count)),
        ("translations_ar_count", str(ar_count)),
        ("sha256", checksum),
        ("generated_at", now_iso),
        ("bounds", f"{ISRAEL_MIN_LAT},{ISRAEL_MAX_LAT},{ISRAEL_MIN_LON},{ISRAEL_MAX_LON}")
    ]
    cur.executemany("INSERT INTO catalog_metadata (key, value) VALUES (?, ?);", metadata)
    
    conn.commit()
    
    # Optimize SQLite file size
    cur.execute("PRAGMA optimize;")
    cur.execute("VACUUM;")
    conn.close()
    
    elapsed = time.time() - start_time
    file_size_mb = os.path.getsize(output_sqlite_path) / (1024 * 1024)
    
    print("\n" + "="*50)
    print("✓ STOP CATALOG BUILD COMPLETE")
    print("="*50)
    print(f"Source Records Read:      {total_read}")
    print(f"Stops Inserted:           {total_inserted}")
    print(f"English Translations:     {en_count} ({en_count*100.0/total_inserted:.2f}%)")
    print(f"Arabic Translations:      {ar_count} ({ar_count*100.0/total_inserted:.2f}%)")
    print(f"Skipped (Out of Bounds):  {skipped_bounds}")
    print(f"Catalog DB File:          {output_sqlite_path}")
    print(f"Database Size:            {file_size_mb:.2f} MB")
    print(f"SHA-256 Checksum:         {checksum}")
    print(f"Build Time:               {elapsed:.2f} seconds")
    print("="*50 + "\n")
    
    # 5. Self-Verification
    verify_catalog(output_sqlite_path)

def verify_catalog(sqlite_path):
    print("[*] Running Verification Checks...")
    conn = sqlite3.connect(sqlite_path)
    cur = conn.cursor()
    
    # Check stop 5997
    cur.execute("SELECT stop_id, stop_code, name_he, name_en, name_ar, lat, lon FROM stops WHERE stop_code = 5997;")
    res_5997 = cur.fetchone()
    assert res_5997 is not None, "Stop 5997 not found in catalog!"
    assert res_5997[0] == 11622, f"Stop 5997 stop_id mismatch: expected 11622, got {res_5997[0]}"
    print(f"  ✓ Verified Stop 5997: ID={res_5997[0]}, HE={res_5997[2]}, EN={res_5997[3]}, AR={res_5997[4]}")
    assert res_5997[3] is not None, "Stop 5997 missing English translation!"
    assert res_5997[4] is not None, "Stop 5997 missing Arabic translation!"
    
    # Check stop 2899
    cur.execute("SELECT stop_id, stop_code, name_he, name_en, name_ar, lat, lon FROM stops WHERE stop_code = 2899;")
    res_2899 = cur.fetchone()
    assert res_2899 is not None, "Stop 2899 not found in catalog!"
    assert res_2899[0] == 10168, f"Stop 2899 stop_id mismatch: expected 10168, got {res_2899[0]}"
    print(f"  ✓ Verified Stop 2899: ID={res_2899[0]}, HE={res_2899[2]}, EN={res_2899[3]}, AR={res_2899[4]}")
    assert res_2899[3] is not None, "Stop 2899 missing English translation!"
    assert res_2899[4] is not None, "Stop 2899 missing Arabic translation!"
    
    # Check spatial R-Tree query for Jerusalem center (bbox: 31.78 to 31.82, 35.20 to 35.23)
    t0 = time.perf_counter()
    cur.execute("""
    SELECT s.stop_id, s.stop_code, s.name_he, s.name_en, s.name_ar, s.lat, s.lon
    FROM stops_rtree r
    JOIN stops s ON r.id = s.stop_id
    WHERE r.min_lat >= 31.78 AND r.max_lat <= 31.82
      AND r.min_lon >= 35.20 AND r.max_lon <= 35.23;
    """)
    j_stops = cur.fetchall()
    q_time = (time.perf_counter() - t0) * 1000
    print(f"  ✓ Spatial R-Tree Query (Jerusalem center): {len(j_stops)} stops in {q_time:.2f} ms")
    assert len(j_stops) > 50, "Expected >50 stops in Jerusalem center query"
    
    conn.close()
    print("[*] All Verification Checks PASSED!\n")

if __name__ == "__main__":
    scratch_dir = r"C:\Users\DAVID\.gemini\antigravity\brain\d43808db-5246-418a-9f99-ac0bbef85f87\scratch"
    default_input = os.path.join(scratch_dir, "stops.txt")
    default_output = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Resources", "IsraelStopCatalog.sqlite")
    default_translations = os.path.join(scratch_dir, "translations.txt")
    
    input_path = sys.argv[1] if len(sys.argv) > 1 else default_input
    output_path = sys.argv[2] if len(sys.argv) > 2 else default_output
    trans_path = sys.argv[3] if len(sys.argv) > 3 else default_translations
    
    build_catalog(input_path, output_path, trans_path)
