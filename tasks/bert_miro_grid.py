#!/not-executable/python3
# Grid alignment utilities for Miro sticky notes.
from dataclasses import dataclass
from enum import Enum
from statistics import mean, median
from typing import Collection, Sequence

from bert_miro import StickyNote


class GridSpacingMode(Enum):
    EQUAL = "equal"
    TIGHT = "tight"
    TIGHT_X = "tight_x"
    TIGHT_Y = "tight_y"
    TILED = "tiled"


class UnexpectedGapError(ValueError):
    pass


class MissingGapError(ValueError):
    pass


class OverlappingStickiesError(ValueError):
    pass


class GridAxisAnalyzer:
    """Analyze sticky note positions along one axis and calculates grid assignments."""

    # Configuration
    min_gap_ratio: float = 0.5  # min_gap = ratio * sticky_smaller_size
    max_gap_ratio: float = 10.0  # max_gap = ratio * sticky_smaller_size
    max_blob_ratio: float = 0.75  # max_blob = ratio * axis_size
    distance_ratio_threshold: float = 1.5  # for blob indexing

    def __init__(
        self,
        positions: Sequence[float],
        *,
        sticky_axis_size: float,
        sticky_smaller_size: float,
    ):
        """Initialize with axis data and sticky sizes."""
        self._original_positions = tuple(positions)
        self._sticky_axis_size = sticky_axis_size
        self._sticky_smaller_size = sticky_smaller_size

        self._grid_size: int | None = None
        self._blobs: tuple[tuple[float, ...] | None, ...] | None = None
        self._position_to_index_mapping: dict[float, int] | None = None

    # Access input arguments as properties

    @property
    def positions(self) -> tuple[float, ...]:
        """Original positions in input order."""
        return self._original_positions

    @property
    def sticky_axis_size(self) -> float:
        """Size of sticky along this axis."""
        return self._sticky_axis_size

    @property
    def sticky_smaller_size(self) -> float:
        """Size of sticky along the smaller axis."""
        return self._sticky_smaller_size

    # Dependent results managed using lazy evaluation

    def blobs(self) -> tuple[tuple[float, ...] | None, ...]:
        """Get blobs blobs (groups of nearby positions)."""
        if self._blobs is None:
            self._build_blobs_and_grid_size()
        assert self._blobs is not None
        return self._blobs

    def grid_size(self) -> int:
        """Get number of rows/columns in grid."""
        if self._grid_size is None:
            self._build_blobs_and_grid_size()
        assert self._grid_size is not None
        return self._grid_size

    def position_to_index_mapping(self) -> dict[float, int]:
        """Get the position -> grid index mapping."""
        if self._position_to_index_mapping is None:
            self._position_to_index_mapping = self._build_position_to_index_mapping(
                self.blobs()
            )
        assert self._position_to_index_mapping is not None
        return self._position_to_index_mapping

    # Other dependent results

    def calculate_blob_median(self, index: int) -> float | None:
        """Calculate the median of one of the blobs."""
        blob = self.blobs()[index]
        if blob is None:
            return None
        blob_set = set(blob)
        blob_positions = [p for p in self.positions if p in blob_set]
        return median(blob_positions)

    def calculate_blob_mean(self, index: int) -> float | None:
        """Calculate the mean of one of the blobs."""
        blob = self.blobs()[index]
        if blob is None:
            return None
        blob_set = set(blob)
        blob_positions = [p for p in self.positions if p in blob_set]
        return mean(blob_positions)

    # Private methods

    def _build_blobs_and_grid_size(self) -> None:
        """Calculate blobs (groups of nearby positions) and grid size."""
        assert self._blobs is None
        blob_collection = self._separate_into_blobs()
        blob_indices = self._assign_blob_indices(blob_collection)
        self._grid_size = max(blob_indices) + 1  # needed for _make_blob_array()
        self._blobs = self._make_blob_array(blob_collection, blob_indices)

    def _separate_into_blobs(self) -> list[list[float]]:
        """1D clustering based on gap detection."""
        min_gap_size = self.sticky_smaller_size * self.min_gap_ratio
        max_gap_size = self.sticky_smaller_size * self.max_gap_ratio
        max_blob_size = self.sticky_axis_size * self.max_blob_ratio

        positions = list(self.positions)
        positions.sort()
        assert len(positions) > 0

        blobs: list[list[float]] = [[]]
        prev_pos = positions[0]

        while positions:
            pos = positions.pop(0)
            dpos = pos - prev_pos
            assert dpos >= 0.0, "Positions should have been sorted"

            if dpos > max_gap_size:
                raise UnexpectedGapError(
                    f"There is a large gap ({dpos}) between the stickies"
                )
            if dpos > min_gap_size:
                blobs.append([])  # start a new blob

            blobs[-1].append(pos)
            prev_pos = pos

        for blob in blobs:
            bsize = blob[-1] - blob[0]
            if bsize > max_blob_size:
                raise UnexpectedGapError(
                    f"There is no gap in a large ({bsize}) set of stickies"
                )

        return blobs

    def _assign_blob_indices(self, blobs: Sequence[Collection[float]]) -> list[int]:
        """Assign grid indices to blobs."""
        blob_centers = [mean(b) for b in blobs]
        blob_distances = [
            blob_centers[i + 1] - blob_centers[i] for i in range(len(blob_centers) - 1)
        ]

        blob_indices = [0]

        if len(blob_distances) > 0:
            blob_distances_1 = [min(blob_distances)]

            while True:
                quantum = mean(blob_distances_1)
                blob_distance_threshold = quantum * self.distance_ratio_threshold
                next_blob_distances_1 = [
                    bd for bd in blob_distances if bd <= blob_distance_threshold
                ]

                if len(next_blob_distances_1) == len(blob_distances_1):
                    break

                blob_distances_1 = next_blob_distances_1

            blob_steps = [round(bd / quantum) for bd in blob_distances]

            for bs in blob_steps:
                blob_indices.append(blob_indices[-1] + bs)

        assert len(blob_indices) == len(blobs)
        return blob_indices

    def _make_blob_array(
        self, blob_collection: Sequence[list[float]], blob_indices: Sequence[int]
    ) -> tuple[tuple[float, ...] | None, ...]:
        assert len(blob_collection) == len(blob_indices)
        assert self._grid_size is not None
        blobs: list[tuple[float, ...] | None] = [None] * self._grid_size
        for i in range(len(blob_collection)):
            assert (
                blobs[blob_indices[i]] is None
            ), "Blob index assigned to multiple blobs"
            blobs[blob_indices[i]] = tuple(blob_collection[i])
        assert (
            blobs[0] is not None and blobs[-1] is not None
        ), "First and last blobs should not be empty"
        return tuple(blobs)

    def _build_position_to_index_mapping(
        self, blobs: Sequence[tuple[float, ...] | None]
    ) -> dict[float, int]:
        """Create position -> grid index mapping."""
        mapping: dict[float, int] = {}
        for i in range(len(blobs)):
            blob = blobs[i]
            if blob is not None:
                for pos in blob:
                    mapping[pos] = i
        return mapping


class GridAxisSpacingGenerator:
    """Calculates spacing and new positions for one axis."""

    def __init__(
        self,
        *,
        previous_min: float,
        previous_max: float,
        grid_size: int,
    ):
        self._previous_min = previous_min
        self._previous_max = previous_max
        self._grid_size = grid_size
        assert self._previous_max >= self._previous_min
        assert self._grid_size >= 1
        assert (self._previous_max > self._previous_min) or self._grid_size == 1

    def generate(self, spacing: float) -> list[float]:
        """Calculate spacing based on a provided spacing value."""
        center = (self._previous_min + self._previous_max) / 2.0
        new_index_positions = [
            center + (g - (self._grid_size - 1) / 2) * spacing
            for g in range(self._grid_size)
        ]
        return new_index_positions

    def equal_spacing(self) -> float:
        """Calculate equal spacing based on the previous size."""
        spacing = (self._previous_max - self._previous_min) / max(
            self._grid_size - 1, 1
        )
        return spacing


class GridSpacingGenerator:
    """Calculates spacing and new positions for both axes."""

    def __init__(
        self,
        *,
        previous_x_min: float,
        previous_x_max: float,
        x_grid_size: int,
        x_item_size: float,
        previous_y_min: float,
        previous_y_max: float,
        y_grid_size: int,
        y_item_size: float,
    ):
        self._x_generator = GridAxisSpacingGenerator(
            previous_min=previous_x_min,
            previous_max=previous_x_max,
            grid_size=x_grid_size,
        )
        self._x_size = x_item_size
        self._y_generator = GridAxisSpacingGenerator(
            previous_min=previous_y_min,
            previous_max=previous_y_max,
            grid_size=y_grid_size,
        )
        self._y_size = y_item_size

    def spacing(self, mode: GridSpacingMode) -> tuple[float, float]:
        """Generate spacing based on mode."""
        smaller_size = min(self._x_size, self._y_size)

        tight_size_x = smaller_size
        # found empirically so gaps between stickies look equal:
        tight_size_y = smaller_size * 1.025

        if mode == GridSpacingMode.EQUAL:
            return (
                self._x_generator.equal_spacing(),
                self._y_generator.equal_spacing(),
            )
        elif mode == GridSpacingMode.TIGHT:
            return (
                tight_size_x,
                tight_size_y,
            )
        elif mode == GridSpacingMode.TIGHT_X:
            return (
                tight_size_x,
                self._y_generator.equal_spacing(),
            )
        elif mode == GridSpacingMode.TIGHT_Y:
            return (
                self._x_generator.equal_spacing(),
                tight_size_y,
            )
        elif mode == GridSpacingMode.TILED:
            return (
                self._x_size,
                self._y_size,
            )
        else:
            raise ValueError(f"Unknown spacing mode {mode!r}")

    def generate(self, mode: GridSpacingMode) -> tuple[list[float], list[float]]:
        """Generate spacing based on mode."""
        spacing = self.spacing(mode)
        return (
            self._x_generator.generate(spacing[0]),
            self._y_generator.generate(spacing[1]),
        )


class GridAxisRealigner:
    """Readjusts positions for one axis to minimize number of moves."""

    def __init__(
        self,
        *,
        previous_positions: Sequence[float],
    ):
        self._previous_positions = previous_positions

    def find_offset(self, positions: Sequence[float]) -> float:
        """Shift positions to minimize movement based on previous positions."""
        assert len(positions) == len(self._previous_positions)
        moved_by = [p - pp for p, pp in zip(positions, self._previous_positions)]
        candidates = list(set(moved_by))
        num_nearby_points = {
            c: len([mb for mb in moved_by if abs(mb - c) < 0.1]) for c in candidates
        }
        num_close_points = {
            c: len([mb for mb in moved_by if abs(mb - c) < 1e-6]) for c in candidates
        }
        best = max(
            candidates,
            key=lambda c: (num_nearby_points[c], num_close_points[c], -abs(c)),
        )
        return -best


class GridRealigner:
    """Readjusts positions for each axis to minimize number of moves."""

    def __init__(
        self,
        *,
        previous_x_positions: Sequence[float],
        previous_y_positions: Sequence[float],
    ):
        self._x_realigner = GridAxisRealigner(
            previous_positions=previous_x_positions,
        )
        self._y_realigner = GridAxisRealigner(
            previous_positions=previous_y_positions,
        )

    def find_offset(
        self, x_positions: Sequence[float], y_positions: Sequence[float]
    ) -> tuple[float, float]:
        """Shift positions to minimize movement for each axis."""
        return (
            self._x_realigner.find_offset(x_positions),
            self._y_realigner.find_offset(y_positions),
        )


class StickyNoteGrid:
    """Manage sticky note grid analysis."""

    @dataclass
    class _Data:
        """Container for a sticky note and its original position."""

        sticky_note: StickyNote
        original_position: tuple[float, float]

    def __init__(
        self,
        sticky_notes: Collection[StickyNote],
    ):
        """Initialize with a list of stickies."""
        self._data: dict[str, StickyNoteGrid._Data] = {}
        for sn in sticky_notes:
            pos = sn.relative_position
            assert pos is not None, f"Sticky note {sn.id} has no position"
            self._data[sn.id] = StickyNoteGrid._Data(
                sticky_note=sn, original_position=pos
            )
        self._most_common_sticky_dimensions: tuple[float, float] | None = None
        self._analyzers: tuple[GridAxisAnalyzer, GridAxisAnalyzer] | None = None
        self._generator: GridSpacingGenerator | None = None
        self._realigner: GridRealigner | None = None
        self._index_positions: dict[
            GridSpacingMode, tuple[list[float], list[float]]
        ] = {}

    # Access input arguments (and closely related fixed data) as properties

    @property
    def sticky_notes(self) -> tuple[StickyNote, ...]:
        """Original positions in input order."""
        return tuple(data.sticky_note for data in self._data.values())

    @property
    def original_positions(self) -> tuple[tuple[float, float], ...]:
        """Original positions in input order."""
        return tuple(data.original_position for data in self._data.values())

    @property
    def original_x_positions(self) -> tuple[float, ...]:
        """Original X positions in input order."""
        return tuple(data.original_position[0] for data in self._data.values())

    @property
    def original_y_positions(self) -> tuple[float, ...]:
        """Original Y positions in input order."""
        return tuple(data.original_position[1] for data in self._data.values())

    # Dependent results managed using lazy evaluation

    def sticky_original_position(self, sticky: StickyNote) -> tuple[float, float]:
        """Get the original position of a sticky note."""
        return self._data[sticky.id].original_position  # error if not in data

    def grid_size(self) -> tuple[int, int]:
        """Get number of rows/columns in grid."""
        analyzers = self._get_analyzers()
        return (analyzers[0].grid_size(), analyzers[1].grid_size())

    def sticky_grid_indices(self, sticky: StickyNote) -> tuple[int, int]:
        """Get the grid position of a sticky note."""
        position = self._data[sticky.id].original_position  # error if not in data
        analyzers = self._get_analyzers()
        grid_position = (
            analyzers[0].position_to_index_mapping()[position[0]],
            analyzers[1].position_to_index_mapping()[position[1]],
        )
        return grid_position

    def sticky_new_position(
        self, sticky: StickyNote, mode: GridSpacingMode
    ) -> tuple[float, float]:
        """Get the new position of a sticky note."""
        grid_indices = self.sticky_grid_indices(sticky)
        index_positions = self._get_index_positions(mode)
        return (
            index_positions[0][grid_indices[0]],
            index_positions[1][grid_indices[1]],
        )

    def most_common_sticky_dimensions(self) -> tuple[float, float]:
        """Get the most common sticky size."""
        if self._most_common_sticky_dimensions is None:
            self._most_common_sticky_dimensions = (
                self._calculate_most_common_dimensions()
            )
        assert self._most_common_sticky_dimensions is not None
        return self._most_common_sticky_dimensions

    # Other public methods

    def new_spacing(self, mode: GridSpacingMode) -> tuple[float, float]:
        """Get the new grid spacing."""
        return self._get_generator().spacing(mode)

    def check_grid_overlaps(self) -> None:
        """Ensure each grid cell has at most one sticky."""
        grid_size = self.grid_size()
        grid: list[list[list[StickyNote]]] = [
            [[] for _ in range(grid_size[1])] for _ in range(grid_size[0])
        ]

        for sticky in self.sticky_notes:
            x_idx, y_idx = self.sticky_grid_indices(sticky)
            grid[x_idx][y_idx].append(sticky)

        for column in grid:
            for cell in column:
                if len(cell) > 1:
                    raise OverlappingStickiesError(
                        f"Multiple stickies in the same cell: {', '.join(repr(s.text) for s in cell)}"
                    )

    # Private methods with lazy evaluation

    def _get_analyzers(self) -> tuple[GridAxisAnalyzer, GridAxisAnalyzer]:
        """Get or create analyzers for both axes."""
        if self._analyzers is None:
            self._analyzers = self._create_analyzers()
        assert self._analyzers is not None
        return self._analyzers

    def _get_generator(self) -> GridSpacingGenerator:
        """Get or create a generator for spacing calculations."""
        if self._generator is None:
            self._generator = self._create_generator()
        assert self._generator is not None
        return self._generator

    def _get_realigner(self) -> GridRealigner:
        """Get or create a realigner for spacing calculations."""
        if self._realigner is None:
            self._realigner = self._create_realigner()
        assert self._realigner is not None
        return self._realigner

    def _get_index_positions(
        self, mode: GridSpacingMode
    ) -> tuple[list[float], list[float]]:
        """Get or create a index_positions for spacing calculations."""
        if mode not in self._index_positions:
            self._index_positions[mode] = self._calculate_index_positions(mode)
        return self._index_positions[mode]

    # Other private methods

    def _calculate_most_common_dimensions(self) -> tuple[float, float]:
        """Calculate the most common sticky size."""
        size_counts: dict[tuple[float, float], int] = {}
        for sticky in self.sticky_notes:
            sticky_size = sticky.size
            assert sticky_size is not None, f"Sticky note {sticky.id} has no size"
            if sticky_size not in size_counts:
                size_counts[sticky_size] = 0
            size_counts[sticky_size] += 1
        most_common_size, _ = max(size_counts.items(), key=lambda kv: kv[1])
        return most_common_size

    def _calculate_index_positions(
        self, mode: GridSpacingMode
    ) -> tuple[list[float], list[float]]:
        """Calculate the index positions."""
        # Get basic positions.
        raw_positions = self._get_generator().generate(mode)
        # Realign.
        # We need to repeat positions as in the original, to get correct weighting.
        analyzers = self._get_analyzers()
        repeated_raw_x = [
            raw_positions[0][analyzers[0].position_to_index_mapping()[x]]
            for x in self.original_x_positions
        ]
        repeated_raw_y = [
            raw_positions[1][analyzers[1].position_to_index_mapping()[y]]
            for y in self.original_y_positions
        ]
        offset = self._get_realigner().find_offset(repeated_raw_x, repeated_raw_y)
        return (
            [x + offset[0] for x in raw_positions[0]],
            [y + offset[1] for y in raw_positions[1]],
        )

    def _create_analyzers(self) -> tuple[GridAxisAnalyzer, GridAxisAnalyzer]:
        """Create analyzers for both axes."""
        most_common_size = self.most_common_sticky_dimensions()
        analyzer_x = GridAxisAnalyzer(
            positions=self.original_x_positions,
            sticky_axis_size=most_common_size[0],
            sticky_smaller_size=min(most_common_size),
        )
        analyzer_y = GridAxisAnalyzer(
            positions=self.original_y_positions,
            sticky_axis_size=most_common_size[1],
            sticky_smaller_size=min(most_common_size),
        )
        return analyzer_x, analyzer_y

    def _create_generator(self) -> GridSpacingGenerator:
        """Create a generator for spacing calculations."""
        analyzers = self._get_analyzers()
        x_min = analyzers[0].calculate_blob_median(0)
        x_max = analyzers[0].calculate_blob_median(-1)
        y_min = analyzers[1].calculate_blob_median(0)
        y_max = analyzers[1].calculate_blob_median(-1)
        assert (
            x_min is not None
            and x_max is not None
            and y_min is not None
            and y_max is not None
        )
        most_common_size = self.most_common_sticky_dimensions()
        generator = GridSpacingGenerator(
            previous_x_min=x_min,
            previous_x_max=x_max,
            x_grid_size=analyzers[0].grid_size(),
            x_item_size=most_common_size[0],
            previous_y_min=y_min,
            previous_y_max=y_max,
            y_grid_size=analyzers[1].grid_size(),
            y_item_size=most_common_size[1],
        )
        return generator

    def _create_realigner(self) -> GridRealigner:
        """Create a realigner for spacing calculations."""
        realigner = GridRealigner(
            previous_x_positions=self.original_x_positions,
            previous_y_positions=self.original_y_positions,
        )
        return realigner
