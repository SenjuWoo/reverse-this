"""Prove product selection excludes private working state, with actual local Git objects."""
import hashlib, importlib.util, json, os, subprocess, tempfile, unittest, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('delivery',ROOT/'scripts/build_release.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)

class ProductTests(unittest.TestCase):
    @unittest.skipUnless(os.name=='nt','Windows product entrypoints')
    def test_actual_extracted_selftest_and_plan(self):
        with tempfile.TemporaryDirectory(prefix='Reverse product Ω ! ') as td:
            base=Path(td); archive=base/'product.zip';builder.build(ROOT,archive)
            with zipfile.ZipFile(archive) as z:z.extractall(base)
            version=(ROOT/'VERSION').read_text(encoding='utf-8-sig').strip()
            product=base/f'Reverse-This-{version}'
            for switch in ('-SelfTest','-Plan'):
                result=subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(product/'Install-Modkit.ps1'),switch],capture_output=True,text=True,timeout=30)
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertFalse((product/'sandbox').exists(),'Read-only entrypoints wrote product state')

    def test_frozen_product_reproducible_private_files_absent_and_existing_output_preserved(self):
        with tempfile.TemporaryDirectory(prefix='Reverse Ω ! ') as td:
            root=Path(td)
            def git(*args):
                return subprocess.run(['git','-C',str(root),*args],check=True,capture_output=True)
            git('init','-q');git('config','user.name','Fixture');git('config','user.email','fixture@example.invalid')
            for name in builder.PRODUCT_FILES|{'catalog/tools.json','STATE.md','CHANGELOG.txt','tests/private.py','docs/CHANGELOG.md'}:
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('1.0.0' if name=='VERSION' else 'original')
            git('add','.');git('commit','-qm','fixture')
            (root/'docs/private.txt').write_text('untracked private');(root/'sandbox').mkdir();(root/'sandbox/secret.txt').write_text('private')
            (root/'README.md').write_text('uncommitted change')
            a=root/'a.zip';b=root/'b.zip'
            receipt=builder.build(root,a);builder.build(root,b)
            self.assertEqual(a.read_bytes(),b.read_bytes())
            with zipfile.ZipFile(a) as archive:
                prefix='Reverse-This-1.0.0/'
                names={n.removeprefix(prefix) for n in archive.namelist()}
                self.assertEqual(names,builder.PRODUCT_FILES|{'catalog/tools.json','RELEASE.json'})
                self.assertEqual(archive.read(prefix+'README.md'),b'original')
                manifest=json.loads(archive.read(prefix+'RELEASE.json'))
                self.assertEqual(manifest['commit'],receipt['commit'])
                for row in manifest['files']:
                    self.assertEqual(row['sha256'],hashlib.sha256(archive.read(prefix+row['path'])).hexdigest())
            before=a.read_bytes()
            with self.assertRaises(FileExistsError):builder.build(root,a)
            self.assertEqual(a.read_bytes(),before)

if __name__=='__main__':unittest.main()
