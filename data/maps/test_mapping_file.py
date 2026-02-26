
#map key:
#scprit run: python data/maps/test_mapping_file.py
#0 = empty
#1 = node
#2 = path

import json
import os


def load_json(filename="ATL JSON.json"):
    """Load JSON data from a file located next to this script."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(script_dir, filename)
    with open(path) as f:
        return json.load(f)


def build_grid(data):
    """Return a 2D grid representation of the floor plan.

    The grid uses:
      0 - empty
      1 - node
      2 - path
    """
    floor = data["building"]["floors"][0]
    nodes = floor["nodes"]
    edges = floor["edges"]

    coords = [node["position"] for node in nodes]
    xs = [c[0] for c in coords]
    ys = [c[1] for c in coords]

    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)

    width = max_x - min_x + 1
    height = max_y - min_y + 1

    shift_x = abs(min_x)
    shift_y = abs(min_y)

    grid = [[0 for _ in range(width)] for _ in range(height)]
    node_positions = {}

    for node in nodes:
        x, y = node["position"]
        nx = x + shift_x
        ny = y + shift_y
        node_positions[node["id"]] = (nx, ny)
        grid[ny][nx] = 1

    for edge in edges:
        x1, y1 = node_positions[edge["from_id"]]
        x2, y2 = node_positions[edge["to_id"]]
        if x1 == x2:  # vertical
            for y in range(min(y1, y2), max(y1, y2) + 1):
                grid[y][x1] = 2
        elif y1 == y2:  # horizontal
            for x in range(min(x1, x2), max(x1, x2) + 1):
                grid[y1][x] = 2

    for x, y in node_positions.values():
        grid[y][x] = 1

    return grid


def print_grid(grid):
    for row in reversed(grid):
        print(row)


def visualize_grid(grid):
    """Show the grid using matplotlib; print instructions if packages missing."""
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except ModuleNotFoundError:
        print("matplotlib/numpy not installed. install with: pip install matplotlib numpy")
        return

    plt.imshow(np.array(grid), origin="lower")
    plt.colorbar()
    plt.show()


def main():
    data = load_json()
    grid = build_grid(data)
    print_grid(grid)
    visualize_grid(grid)


if __name__ == "__main__":
    main()

