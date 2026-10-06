#!/usr/bin/env python3
"""Build the abapGit offline zip of PIA for SAP: one local package $ZPIA (folder logic FULL, src/ = $ZPIA).
Leaves out what only OSG needs (zcl_pia_20_b_osg_store, OSG-style *.sicf.xml) and debug code (mock_run);
SICF nodes come from osg-probe/a4h/abapgit-front in abapGit's naming."""
import os, sys, zipfile, glob
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
version = sys.argv[1] if len(sys.argv) > 1 else "dev"
out = os.path.join(root, "release", f"pia-{version}-abapgit.zip")
skip = ("zcl_pia_20_b_osg_store.", "zcl_pia_90_mock_run.", "package.devc.xml")
files = []
for f in sorted(glob.glob(os.path.join(root, "src", "**", "*"), recursive=True)):
    b = os.path.basename(f)
    if not os.path.isfile(f) or not (b.endswith(".abap") or b.endswith(".xml")):
        continue
    if b.startswith(skip) or b.endswith(".sicf.xml"):
        continue
    files.append((f, "src/" + b))
front = os.path.join(root, "osg-probe", "a4h", "abapgit-front")
for f in sorted(glob.glob(os.path.join(front, "src", "*.sicf.xml"))):
    files.append((f, "src/" + os.path.basename(f)))
pkg = """<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_DEVC" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DEVC>
    <CTEXT>PIA - ABAP coding agent written in ABAP</CTEXT>
   </DEVC>
  </asx:values>
 </asx:abap>
</abapGit>
"""
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.write(os.path.join(front, ".abapgit.xml"), ".abapgit.xml")
    z.writestr("src/package.devc.xml", pkg)
    for f, name in files:
        z.write(f, name)
names = [n for n in zipfile.ZipFile(out).namelist()]
objs = sorted({n.split("/")[-1].split(".")[0] + "." + n.split(".")[-2] for n in names if n.startswith("src/") and n.count(".") >= 2 and "package" not in n})
print(out, len(names), "files,", len(objs), "objects")
for o in objs: print("  ", o)
