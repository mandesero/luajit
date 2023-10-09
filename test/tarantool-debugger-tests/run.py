# Runner script for compatibility with `prove`.
import sys

from config import runner
from test_base import Spec

with open(sys.argv[1], 'r') as stream:
    runner(Spec(stream.read()).blocks)
