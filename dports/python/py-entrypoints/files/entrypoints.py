"""Discover and load entry points from installed packages."""
import configparser
from contextlib import contextmanager
import glob
from importlib import import_module
import io
import itertools
import os.path as osp
import re
import sys
import warnings
import zipfile

entry_point_pattern = re.compile(r"""
(?P<modulename>\w+(\.\w+)*)
(:(?P<objectname>\w+(\.\w+)*))?
\s*
(\[(?P<extras>.+)\])?
$
""", re.VERBOSE)

__version__ = '0.2'

class BadEntryPoint(Exception):
    """Raised when an entry point can't be parsed.
    """
    def __init__(self, epstr):
        self.epstr = epstr

    def __str__(self):
        return "Couldn't parse entry point spec: %r" % self.epstr

    @staticmethod
    @contextmanager
    def err_to_warnings():
        try:
            yield
        except BadEntryPoint as e:
            warnings.warn(str(e))

class NoSuchEntryPoint(Exception):
    """Raised by :func:`get_single` when no matching entry point is found."""
    def __init__(self, group, name):
        self.group = group
        self.name = name

    def __str__(self):
        return "No {!r} entry point found in group {!r}".format(self.name, self.group)


class EntryPoint(object):
    def __init__(self, name, module_name, object_name, extras=None, distro=None):
        self.name = name
        self.module_name = module_name
        self.object_name = object_name
        self.extras = extras
        self.distro = distro

    def __repr__(self):
        return "EntryPoint(%r, %r, %r, %r)" % \
            (self.name, self.module_name, self.object_name, self.distro)

    def load(self):
        """Load the object to which this entry point refers.
        """
        mod = import_module(self.module_name)
        obj = mod
        if self.object_name:
            for attr in self.object_name.split('.'):
                obj = getattr(obj, attr)
        return obj
    
    @classmethod
    def from_string(cls, epstr, name, distro=None):
        """Parse an entry point from the syntax in entry_points.txt

        :param str epstr: The entry point string (not including 'name =')
        :param str name: The name of this entry point
        :param Distribution distro: The distribution in which the entry point was found
        :rtype: EntryPoint
        :raises BadEntryPoint: if *epstr* can't be parsed as an entry point.
        """
        m = entry_point_pattern.match(epstr)
        if m:
            mod, obj, extras = m.group('modulename', 'objectname', 'extras')
            if extras is not None:
                extras = re.split(',\s*', extras)
            return cls(name, mod, obj, extras, distro)
        else:
            raise BadEntryPoint(epstr)

class Distribution(object):
    def __init__(self, name, version):
        self.name = name
        self.version = version
    
    def __repr__(self):
        return "Distribution(%r, %r)" % (self.name, self.version)


def iter_files_distros(path=None, repeated_distro='first'):
    if path is None:
        path = sys.path

    # Distributions found earlier in path will shadow those with the same name
    # found later. If these distributions used different module names, it may
    # actually be possible to import both, but in most cases this shadowing
    # will be correct.
    distro_names_seen = set()

    for folder in path:
        if folder.rstrip('/\\').endswith('.egg'):
            # Gah, eggs
            egg_name = osp.basename(folder)
            if '-' in egg_name:
                distro = Distribution(*egg_name.split('-')[:2])

                if (repeated_distro == 'first') \
                        and (distro.name in distro_names_seen):
                    continue
                distro_names_seen.add(distro.name)
            else:
                distro = None
            
            if osp.isdir(folder):
                ep_path = osp.join(folder, 'EGG-INFO', 'entry_points.txt')
                if osp.isfile(ep_path):
                    cp = configparser.ConfigParser()
                    cp.read(ep_path)
                    yield cp, distro

            elif zipfile.is_zipfile(folder):
                z = zipfile.ZipFile(folder)
                try:
                    info = z.getinfo('EGG-INFO/entry_points.txt')
                except KeyError:
                    continue
                cp = configparser.ConfigParser()
                with z.open(info) as f:
                    fu = io.TextIOWrapper(f)
                    cp.read_file(fu,
                        source=osp.join(folder, 'EGG-INFO', 'entry_points.txt'))
                yield cp, distro
            
        for path in itertools.chain(
            glob.iglob(osp.join(folder, '*.dist-info', 'entry_points.txt')),
            glob.iglob(osp.join(folder, '*.egg-info', 'entry_points.txt'))
        ):
            distro_name_version = osp.splitext(osp.basename(osp.dirname(path)))[0]
            if '-' in distro_name_version:
                distro = Distribution(*distro_name_version.split('-', 1))

                if (repeated_distro == 'first') \
                        and (distro.name in distro_names_seen):
                    continue
                distro_names_seen.add(distro.name)
            else:
                distro = None
            cp = configparser.ConfigParser()
            cp.read(path)
            yield cp, distro

def get_single(group, name, path=None):
    """Find a single entry point.

    Returns an :class:`EntryPoint` object, or raises :exc:`NoSuchEntryPoint`
    if no match is found.
    """
    for config, distro in iter_files_distros(path=path):
        if (group in config) and (name in config[group]):
            epstr = config[group][name]
            with BadEntryPoint.err_to_warnings():
                return EntryPoint.from_string(epstr, name, distro)

    raise NoSuchEntryPoint(group, name)

def get_group_named(group, path=None):
    """Find a group of entry points with unique names.

    Returns a dictionary of names to :class:`EntryPoint` objects.
    """
    result = {}
    for ep in get_group_all(group, path=path):
        if ep.name not in result:
            result[ep.name] = ep
    return result

def get_group_all(group, path=None):
    """Find all entry points in a group.

    Returns a list of :class:`EntryPoint` objects.
    """
    result = []
    for config, distro in iter_files_distros(path=path):
        if group in config:
            for name, epstr in config[group].items():
                with BadEntryPoint.err_to_warnings():
                    result.append(EntryPoint.from_string(epstr, name, distro))

    return result

if __name__ == '__main__':
    import pprint
    pprint.pprint(get_group_all('console_scripts'))
