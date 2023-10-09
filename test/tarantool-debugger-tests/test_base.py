# This file provides a pythonic implementation of similar to Perl's Test::Base
# module functionality for declarative testing.
# See https://metacpan.org/pod/Test::Base#Rolling-Your-Own-Filters
from config import *  # noqa: F401,F403


class Pipeline(object):
    def __init__(self, funcs):
        self.funcs = funcs

    def __call__(self, data):
        for func in self.funcs:
            data = func(data)
        return data


class Section(object):
    def __init__(self, name, pipeline):
        self.name = name
        self.data = ''
        self.pipeline = pipeline


class Block(object):
    def __init__(self, name):
        self.name = name
        self.description = ''
        self.sections = []


class Spec(object):
    def __init__(
        self,
        spec,
        block_descriptor='## ',
        section_descriptor='### ',
    ):
        self.blocks = []
        self.block_descriptor = block_descriptor
        self.section_descriptor = section_descriptor
        self.parse_spec(spec)

    def _is_block_start(self, line):
        return line.startswith(self.block_descriptor)

    def _is_section_start(self, line):
        return line.startswith(self.section_descriptor)

    def _is_description(self, line):
        return not self.blocks[-1].sections

    def parse_spec(
        self,
        spec,
    ):
        spec = spec.strip().splitlines(True)

        for line in spec:
            if self._is_block_start(line):
                name = line.lstrip(self.block_descriptor).strip()
                self.blocks.append(Block(name))

            elif self._is_section_start(line):
                meta = line.lstrip(self.section_descriptor).strip().split()
                name = meta[0]
                pipeline = Pipeline([globals()[fname] for fname in meta[1:]])
                self.blocks[-1].sections.append(Section(name, pipeline))

            elif self._is_description(line):
                self.blocks[-1].description += line

            else:
                self.blocks[-1].sections[-1].data += line
