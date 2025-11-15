import random

import pytest

from wheel_of_name import Spinner


def test_spin_removes_only_single_match():
    spinner = Spinner(["Alice", "Bob", "Alice"], rng=random.Random(1))
    winner = spinner.spin(remove=True)
    assert winner == "Alice"
    assert spinner.remaining == ("Bob", "Alice")


def test_spin_empty_wheel_raises():
    spinner = Spinner(["Alice"], rng=random.Random(0))
    spinner.spin(remove=True)

    with pytest.raises(ValueError):
        spinner.spin(remove=True)


def test_sanitise_discards_blank_entries():
    spinner = Spinner([" Alice ", "", None, "Bob"], rng=random.Random(0))
    assert spinner.remaining == ("Alice", "Bob")
