#!/usr/bin/env python3
"""Prepare GeoServer and its stable extensions for the image, at build time.

Unpacks the WAR, downloads every extension zip found in the plugin listing, removes
native libraries built for other platforms from all jars, and stores each extension
jar once in a pool keyed by its SHA-256. One manifest per extension lists the jars
it needs, as "<sha256> <file name>" lines, for install-extensions.sh to copy at startup.

Usage: pack-extensions.py <war zip path or URL> <plugin listing URL> <arch> <output dir>
"""
import hashlib
import http.client
import os
import re
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urljoin

NATIVE = re.compile(r'\.(so|dll|dylib|jnilib)(\.\d+)*$|\.so_')
SIGNATURE = re.compile(r'META-INF/[^/]+\.SF$', re.IGNORECASE)
# Path separators around platform words, so "darwin" is not read as "win"
B, E = r'(?:^|[/_.-])', r'(?:[/_.-]|\d|$)'
OTHER_OS = re.compile(B + r'(win(32|64|dows)?|mac(os|osx)?|osx|darwin|\w*bsd|android|aix|sunos|solaris|musl|alpine)' + E
                      + r'|\.(dll|dylib|jnilib)$')
X86_64 = re.compile(r'x86[-_]?64|amd64|x64')
AARCH64 = re.compile(r'aarch_?64|arm64')
OTHER_ARCH = re.compile(B + r'(x86|i[3-6]86|arm\w*|ppc\w*|s390x?|riscv\w*|loong\w*|mips\w*|sparc\w*)' + E)
ARCHS = {'amd64': 'x86_64', 'arm64': 'aarch64'}


def foreign(entry, arch):
    """True when a native entry names another OS or another CPU; entries naming neither are kept."""
    path = entry.lower()
    if OTHER_OS.search(path):
        return True
    found = 'x86_64' if X86_64.search(path) else 'aarch64' if AARCH64.search(path) else \
        'other' if OTHER_ARCH.search(path) else None
    return found is not None and found != arch


def strip(src, dst, arch):
    """Copy jar src to dst without foreign natives, returning the bytes removed. Signed jars are copied as is."""
    with zipfile.ZipFile(src) as zin:
        entries = zin.infolist()
        drop = [] if arch is None or any(SIGNATURE.match(e.filename) for e in entries) else \
            [e for e in entries if NATIVE.search(e.filename) and foreign(e.filename, arch)]
        if drop:
            with zipfile.ZipFile(dst + '.tmp', 'w') as zout:
                for e in entries:
                    if e not in drop:
                        with zin.open(e) as r, zout.open(e, 'w') as w:
                            shutil.copyfileobj(r, w)
    if drop:
        os.replace(dst + '.tmp', dst)
        return sum(e.compress_size for e in drop)
    if src != dst:
        shutil.copyfile(src, dst)
    return 0


def sha256(path):
    """Hex SHA-256 of a file."""
    with open(path, 'rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def fetch(url, path, attempts=3):
    """Download a zip file from url to path, retrying on network errors."""
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(url, timeout=120) as r, open(path, 'wb') as f:
                shutil.copyfileobj(r, f)
            if not zipfile.is_zipfile(path):
                raise OSError(f'{url} did not return a zip file')
            return
        except (OSError, http.client.HTTPException) as e:
            if attempt == attempts:
                raise OSError(f'Download of {url} failed after {attempts} attempts: {e}') from e
            print(f'  retrying {url} after: {e}')


def report(name, removed):
    """Print the size of the natives removed from a jar, if any."""
    if removed:
        print(f'  {name}: removed {removed / 2**20:.1f} MB of foreign natives')


def unpack_war(war_zip, webapp, arch):
    """Unpack and strip the WAR, returning the hashes of its jars as released."""
    with zipfile.ZipFile(war_zip) as z, z.open('geoserver.war') as war, zipfile.ZipFile(war) as w:
        w.extractall(webapp)
    lib = os.path.join(webapp, 'WEB-INF', 'lib')
    names = sorted(n for n in os.listdir(lib) if n.endswith('.jar'))
    # Extension jars are matched against the WAR jars as released, so hash before stripping
    hashes = {sha256(os.path.join(lib, n)) for n in names}
    print('Stripping WAR jars')
    for name in names:
        path = os.path.join(lib, name)
        report(name, strip(path, path, arch))
    return hashes


def plugin_zips(listing_url):
    """Absolute URLs of the *-plugin.zip files linked from the listing page, keyed by extension name."""
    # SourceForge serves files from downloads.sourceforge.net, but lists them on sourceforge.net
    base = listing_url.rstrip('/') + '/'
    page = re.sub(r'://downloads\.sourceforge\.net/project/([^/]+)/', r'://sourceforge.net/projects/\1/files/', base)
    with urllib.request.urlopen(page, timeout=120) as r:
        html = r.read().decode('utf-8', 'replace')
    names = sorted(set(re.findall(r'geoserver-[^"/<>\s]+-plugin\.zip', html)))
    parsed = [re.match(r'geoserver-(\d[\w.]*(?:-(?:SNAPSHOT|RC\d*|M\d*))?)-(.+)-plugin\.zip$', n) for n in names]
    versions = {m.group(1) for m in parsed if m}
    if not names or None in parsed or len(versions) != 1:
        sys.exit(f'Expected plugin zips of a single GeoServer version at {page}, found {names}')
    return {m.group(2): urljoin(base, m.group(0)) for m in parsed}


def pack(extension_zip, war_hashes, jars, arch, tmp):
    """Pool the jars of one extension zip that are not in the WAR, returning its manifest lines."""
    lines = []
    with zipfile.ZipFile(extension_zip) as z:
        for e in z.infolist():
            if not e.filename.endswith('.jar'):
                continue
            name = os.path.basename(e.filename)
            src = os.path.join(tmp, 'entry.jar')
            with z.open(e) as r, open(src, 'wb') as w:
                shutil.copyfileobj(r, w)
            key = sha256(src)
            if key in war_hashes:
                continue
            pooled = os.path.join(jars, key + '.jar')
            if not os.path.exists(pooled):
                report(name, strip(src, pooled, arch))
            lines.append(f'{key} {name}\n')
    return lines


def main(war, listing_url, target_arch, out):
    """Unpack the WAR, then download and pool the extensions."""
    arch = ARCHS.get(target_arch)
    if arch is None:
        print(f'No native stripping for architecture {target_arch!r}')
    jars, manifests = os.path.join(out, 'extensions', 'jars'), os.path.join(out, 'extensions', 'manifests')
    os.makedirs(jars)
    os.makedirs(manifests)
    with tempfile.TemporaryDirectory() as tmp:
        if re.match(r'https?://', war):
            print(f'Downloading {war}')
            fetch(war, os.path.join(tmp, 'war.zip'))
            war = os.path.join(tmp, 'war.zip')
        war_hashes = unpack_war(war, os.path.join(out, 'geoserver'), arch)

        zips = plugin_zips(listing_url)
        print(f'Downloading {len(zips)} extensions from {listing_url}')
        with ThreadPoolExecutor(8) as pool:
            list(pool.map(lambda ext: fetch(zips[ext], os.path.join(tmp, ext + '.zip')), zips))

        for ext in zips:
            lines = pack(os.path.join(tmp, ext + '.zip'), war_hashes, jars, arch, tmp)
            with open(os.path.join(manifests, ext + '.txt'), 'w', encoding='ascii') as f:
                f.writelines(lines)
    size = sum(os.path.getsize(os.path.join(jars, j)) for j in os.listdir(jars))
    print(f'Packed {len(zips)} extensions: {len(os.listdir(jars))} jars, {size / 2**20:.0f} MB')


if __name__ == '__main__':
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    main(*sys.argv[1:])
