"""Logic for spinning a wheel of names.

The module provides the :class:`Spinner` class which is responsible for
keeping track of the names on the wheel and choosing a winner.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable, List, Sequence
import random


@dataclass
class Spinner:
    """Spin a wheel of names.

    Parameters
    ----------
    names:
        Iterable of candidate names. Empty strings and ``None`` values are
        ignored.
    rng:
        Optional :class:`random.Random` instance that controls the randomness.
        Supplying a pre-seeded RNG makes tests deterministic.
    """

    names: Sequence[str]
    rng: random.Random = field(default_factory=random.Random)

    def __post_init__(self) -> None:
        sanitized = self._sanitize(self.names)
        if not sanitized:
            raise ValueError("Spinner requires at least one non-empty name")
        # Store the mutable list privately so that outside callers cannot
        # accidentally modify the wheel's state.
        self._names: List[str] = sanitized

    @staticmethod
    def _sanitize(names: Iterable[str]) -> List[str]:
        """Return a cleaned-up list of names.

        ``None`` values and strings made only of whitespace are removed.  The
        strings are also stripped to avoid unexpected leading or trailing
        spaces.
        """

        sanitized: List[str] = []
        for raw in names:
            if raw is None:
                continue
            cleaned = str(raw).strip()
            if cleaned:
                sanitized.append(cleaned)
        return sanitized

    @property
    def remaining(self) -> Sequence[str]:
        """Names that are still on the wheel."""

        return tuple(self._names)

    def spin(self, *, remove: bool = False) -> str:
        """Pick a random name from the wheel.

        Parameters
        ----------
        remove:
            When ``True`` the winner is removed from the wheel.

        Returns
        -------
        str
            The winning name.

        Raises
        ------
        ValueError
            If the wheel has no names to spin.
        """

        if not self._names:
            raise ValueError("Cannot spin an empty wheel")

        winner = self.rng.choice(self._names)

        if remove:
            # ``list.remove`` only removes the first occurrence.  This is
            # important because users expect duplicate entries to stay on the
            # wheel after a spin, minus the single entry that won.  The
            # previous implementation replaced the list with a comprehension
            # that filtered *all* matching names, effectively punishing users
            # for adding duplicate slices to the wheel.  That behaviour made it
            # impossible to weight the wheel by repeating names.  Using
            # ``remove`` fixes the bug while keeping the internal state
            # consistent.
            self._names.remove(winner)

        return winner

    def reset(self, names: Iterable[str]) -> None:
        """Replace the names on the wheel with ``names``."""

        sanitized = self._sanitize(names)
        if not sanitized:
            raise ValueError("Spinner requires at least one non-empty name")
        self._names = sanitized
