#!/usr/bin/env python3
# BatStats — Battery Status
# Copyright (c) 2026 @utama_wira. Lisensi MIT.
#
# Membuat file pintasan "Kirim Baterai ke BatStats" lalu menandatanganinya
# dengan alat resmi macOS (`shortcuts sign`) agar bisa diimpor di iPhone/iPad.
#
#   python3 shortcut/buat_pintasan.py
#
# Hasil: shortcut/Kirim Baterai ke BatStats.shortcut

import os
import plistlib
import subprocess
import sys
import tempfile
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
MODE = os.environ.get("MODE", "people-who-know-me")  # "anyone" butuh akses iCloud penuh
NAME = "Kirim Baterai ke BatStats"
OBJ = "￼"  # penanda posisi variabel di dalam teks


def uid():
    return str(uuid.uuid4()).upper()


def output(u, name):
    return {"OutputUUID": u, "Type": "ActionOutput", "OutputName": name}


def text(s="", attachments=None):
    """Teks dengan variabel. attachments: daftar (posisi, uuid, nama_output)."""
    return {
        "Value": {
            "string": s,
            "attachmentsByRange": {f"{{{pos}, 1}}": output(u, n) for pos, u, n in (attachments or [])},
        },
        "WFSerializationType": "WFTextTokenString",
    }


def item(item_type, key, value):
    return {"WFItemType": item_type, "WFKey": text(key), "WFValue": value}


battery, dev_name, dev_model, dictionary = uid(), uid(), uid(), uid()
TEXT, NUMBER = 0, 3

actions = [
    {"WFWorkflowActionIdentifier": "is.workflow.actions.getbatterylevel",
     "WFWorkflowActionParameters": {"UUID": battery}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.getdevicedetails",
     "WFWorkflowActionParameters": {"UUID": dev_name, "WFDeviceDetail": "Device Name"}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.getdevicedetails",
     "WFWorkflowActionParameters": {"UUID": dev_model, "WFDeviceDetail": "Device Model"}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.dictionary",
     "WFWorkflowActionParameters": {
         "UUID": dictionary,
         "WFItems": {
             "Value": {"WFDictionaryFieldValueItems": [
                 item(TEXT, "name", text(OBJ, [(0, dev_name, "Device Name")])),
                 item(NUMBER, "level", text(OBJ, [(0, battery, "Battery Level")])),
                 item(TEXT, "model", text(OBJ, [(0, dev_model, "Device Model")])),
                 item(TEXT, "source", text("shortcut")),
             ]},
             "WFSerializationType": "WFDictionaryFieldValue",
         },
     }},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.documentpicker.save",
     "WFWorkflowActionParameters": {
         "WFInput": {"Value": output(dictionary, "Dictionary"), "WFSerializationType": "WFTextTokenAttachment"},
         "WFAskWhereToSave": False,
         "WFFileDestinationPath": text(f"BatStats/{OBJ}.json", [(len("BatStats/"), dev_name, "Device Name")]),
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
    "WFWorkflowName": NAME,
}

out = os.path.join(HERE, f"{NAME}.shortcut")
with tempfile.TemporaryDirectory() as tmp:
    unsigned = os.path.join(tmp, "unsigned.shortcut")
    with open(unsigned, "wb") as f:
        plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
    r = subprocess.run(["shortcuts", "sign", "--mode", MODE, "--input", unsigned, "--output", out],
                       capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out):
        sys.exit(f"Gagal menandatangani: {r.stderr or r.stdout}")
print(f"✓ {out}")
