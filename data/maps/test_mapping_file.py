

#map key:
#0 = empty
#1 = node
#2 = path


#Load and Parse JSON
import json
import os

# Build path relative to this script's directory to ensure the JSON file is found
script_dir = os.path.dirname(os.path.abspath(__file__))
json_path = os.path.join(script_dir, "ATL JSON.json")

with open(json_path) as f:
    data = json.load(f)

floor = data["building"]["floors"][0]
nodes = floor["nodes"]
edges = floor["edges"]

#Extract All Coordinates
coords = [node["position"] for node in nodes]
xs = [c[0] for c in coords]
ys = [c[1] for c in coords]

#Compute Grid Boundaries
min_x, max_x = min(xs), max(xs)
min_y, max_y = min(ys), max(ys)

width = max_x - min_x + 1
height = max_y - min_y + 1

# Calculate shifts for normalization (used when placing nodes)
shift_x = abs(min_x)
shift_y = abs(min_y)

#Create Empty Grid
grid = [[0 for _ in range(width)] for _ in range(height)]

#Place Nodes on Grid
node_positions = {}

for node in nodes:
    x, y = node["position"]
    nx = x + shift_x
    ny = y + shift_y

    node_positions[node["id"]] = (nx, ny)
    grid[ny][nx] = 1

#Draw Edges (Paths)
for edge in edges:
    x1, y1 = node_positions[edge["from_id"]]
    x2, y2 = node_positions[edge["to_id"]]

    # Vertical path
    if x1 == x2:
        for y in range(min(y1, y2), max(y1, y2) + 1):
            grid[y][x1] = 2

    # Horizontal path
    elif y1 == y2:
        for x in range(min(x1, x2), max(x1, x2) + 1):
            grid[y1][x] = 2

#After drawing paths, re-mark nodes so they stay as 1.
for x, y in node_positions.values():
    grid[y][x] = 1

#Print Grid Properly
for row in reversed(grid):
    print(row)

#use matplotlib to visualize (optional dependency)
try:
    import matplotlib.pyplot as plt
    import numpy as np
except ModuleNotFoundError:
    plt = None
    np = None


if plt is not None and np is not None:
    plt.imshow(np.array(grid), origin="lower")
    plt.colorbar()
    plt.show()
else:
    print("matplotlib/numpy not available; skipping visualization")