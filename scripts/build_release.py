"""Build the runnable workbench from a frozen Git commit, never a private working tree."""
from __future__ import annotations
import argparse, hashlib, io, json, re, subprocess, zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
PRODUCT_FILES = {'VERSION','LICENSE','README.md','AGENTS.md','CLAUDE.md','Install-Modkit.ps1',
                 'Update-ReverseThis.ps1','Start-IsolatedLab.ps1','install.cmd','catalog/asset-pattern-fixtures.json',
                 'context7.json','kit/README.md','kit/pe_recon.py','kit/aob_gen.py','kit/ghidra_mcp_up.py'}
# The encyclopedia ships with the kit so the local Context7 fallback works offline.
ENCYCLOPEDIA_REQUIRED = {'encyclopedia/README.md','encyclopedia/ROUTING.md','encyclopedia/ERROR-REGISTRY.json'}


def build(root: Path, output: Path, commit: str = 'HEAD') -> dict:
    sha = subprocess.check_output(['git','rev-parse',commit+'^{commit}'],cwd=root,text=True).strip()
    raw = subprocess.check_output(['git','archive','--format=zip',sha],cwd=root)
    files = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as source:
        for entry in source.infolist():
            name = entry.filename
            if entry.is_dir() or not (name in PRODUCT_FILES or name.startswith(('catalog/','docs/','encyclopedia/'))):
                continue
            rel = PurePosixPath(name)
            if rel.is_absolute() or '..' in rel.parts or '\\' in name or ':' in name or ((entry.external_attr >> 16) & 0o170000) == 0o120000:
                raise ValueError('Unsafe product source: '+name)
            if 'changelog' in rel.stem.casefold() and rel.suffix.casefold() in {'.txt','.md','.rst'}:
                continue
            data = source.read(entry)
            if rel.suffix.casefold() in {'.ps1','.cmd','.bat'}:
                data = data.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')
            files[name] = data
    required = PRODUCT_FILES | ENCYCLOPEDIA_REQUIRED | {'catalog/tools.json'}
    if not required <= files.keys():
        raise ValueError('Missing product files: '+str(sorted(required-files.keys())))
    version = files['VERSION'].decode('utf-8-sig').strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+',version):
        raise ValueError('Invalid product version')
    manifest = {'product':'Reverse THIS!','version':version,'commit':sha,'files':[
        {'path':name,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()} for name,data in sorted(files.items())]}
    files['RELEASE.json'] = (json.dumps(manifest,indent=2)+'\n').encode()
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('xb') as stream:
        with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
            for name,data in sorted(files.items()):
                info=zipfile.ZipInfo(f'Reverse-This-{version}/'+name,(2026,10,27,0,0,0))
                info.create_system=3; info.external_attr=0o100644<<16
                archive.writestr(info,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    with zipfile.ZipFile(output) as archive:
        if archive.testzip():
            raise ValueError('Product archive CRC failure')
    return {'version':version,'commit':sha,'files':len(files),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'bytes':output.stat().st_size}


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output',type=Path);parser.add_argument('--commit',default='HEAD')
    args=parser.parse_args()
    print(json.dumps(build(ROOT,args.output,args.commit)))
