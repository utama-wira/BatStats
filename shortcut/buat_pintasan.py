#!/usr/bin/env python3
# BatStats — Battery Status
# Copyright (c) 2026 @utama_wira. Lisensi MIT.
#
# Membuat pintasan "Kirim Baterai ke BatStats" untuk SATU perangkat, lalu menandatanganinya
# dengan alat resmi macOS (`shortcuts sign`) agar bisa diimpor di iPhone/iPad.
#
#   python3 shortcut/buat_pintasan.py --nama "Nama iPhone" --jenis iPhone
#   python3 shortcut/buat_pintasan.py --nama "Nama iPad"   --jenis iPad
#
# --nama  : harus sama dengan Pengaturan › Umum › Mengenai › Nama di perangkat itu,
#           supaya BatStats menggabungkannya dengan perangkat yang sudah dikenal.
# --jenis : iPhone atau iPad (juga menjadi nama file: BatStats/iPhone.json / iPad.json)
#
# Kenapa nama & file ditulis tetap (bukan diambil dari "Dapatkan Detail Perangkat")?
# iOS menganggap detail perangkat sebagai data pribadi dan terus memunculkan pop-up
# "Izinkan … menyimpan item teks ke file?" walau sudah dipilih "Selalu Izinkan".
# Dengan teks tetap, yang dikirim hanya tingkat baterai — tanpa pop-up berulang.

import argparse
import os
import plistlib
import subprocess
import sys
import tempfile
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
TITLE = "Kirim Baterai ke BatStats"
OBJ = "￼"  # penanda posisi variabel di dalam teks

p = argparse.ArgumentParser(description="Buat pintasan BatStats untuk satu perangkat.")
p.add_argument("--nama", required=True, help="nama perangkat persis seperti di Pengaturan")
p.add_argument("--jenis", required=True, choices=["iPhone", "iPad"])
p.add_argument("--mode", default="people-who-know-me", choices=["people-who-know-me", "anyone"],
               help='mode tanda tangan ("anyone" butuh akses iCloud penuh)')
args = p.parse_args()


def uid():
    return str(uuid.uuid4()).upper()


def output(u, name):
    return {"OutputUUID": u, "Type": "ActionOutput", "OutputName": name}


def text(s="", attachments=None):
    """Teks, opsional berisi variabel. attachments: daftar (posisi, uuid, nama_output)."""
    return {
        "Value": {
            "string": s,
            "attachmentsByRange": {f"{{{pos}, 1}}": output(u, n) for pos, u, n in (attachments or [])},
        },
        "WFSerializationType": "WFTextTokenString",
    }


def item(item_type, key, value):
    return {"WFItemType": item_type, "WFKey": text(key), "WFValue": value}


battery, dictionary = uid(), uid()
TEXT, NUMBER = 0, 3

actions = [
    {"WFWorkflowActionIdentifier": "is.workflow.actions.getbatterylevel",
     "WFWorkflowActionParameters": {"UUID": battery}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.dictionary",
     "WFWorkflowActionParameters": {
         "UUID": dictionary,
         "WFItems": {
             "Value": {"WFDictionaryFieldValueItems": [
                 item(TEXT, "name", text(args.nama)),
                 item(NUMBER, "level", text(OBJ, [(0, battery, "Battery Level")])),
                 item(TEXT, "model", text(args.jenis)),
                 item(TEXT, "source", text("shortcut")),
             ]},
             "WFSerializationType": "WFDictionaryFieldValue",
         },
     }},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.documentpicker.save",
     "WFWorkflowActionParameters": {
         "WFInput": {"Value": output(dictionary, "Dictionary"), "WFSerializationType": "WFTextTokenAttachment"},
         "WFAskWhereToSave": False,
         "WFFileDestinationPath": text(f"BatStats/{args.jenis}.json"),
         "WFSaveFileOverwrite": True,
     }},
]

workflow = {
    "WFWorkflowActions": actions,
    "WFWorkflowClientVersion": "2607.0.2",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4292093695, "WFWorkflowIconGlyphNumber": 59511},
    "WFWorkflowImportQuestions": [],
    "WFWorkflowInputContentItemClasses": [],
    "WFWorkflowOutputContentItemClasses": [],
    "WFWorkflowTypes": [],
    "WFQuickActionSurfaces": [],
    "WFWorkflowHasShortcutInputVariables": False,
    "WFWorkflowName": TITLE,
}

out = os.path.join(HERE, f"{TITLE} ({args.jenis}).shortcut")
with tempfile.TemporaryDirectory() as tmp:
    unsigned = os.path.join(tmp, "unsigned.shortcut")
    with open(unsigned, "wb") as f:
        plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
    r = subprocess.run(["shortcuts", "sign", "--mode", args.mode, "--input", unsigned, "--output", out],
                       capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out):
        sys.exit(f"Gagal menandatangani: {r.stderr or r.stdout}")
print(f"✓ {out}")
