import json
import heapq
import math
import os
from typing import Optional

#map data
script_dir = os.path.dirname(os.path.abspath(__file__))
path = os.path.join(script_dir, "ATL JSON.json")
with open(path) as f:
    MAP_JSON = f.read()

# ---------------------------------------------------------------------------
# LANDMARK BOUNDING BOX DEFINITIONS
# Each entry contains the detection metadata: id, label, x, y, width, height.
# (x, y) is the top-left corner of the bounding box in image/pixel space.
# The "center" tuple is derived as (x + width/2, y + height/2).
# ---------------------------------------------------------------------------
LANDMARK_BOXES: dict[str, dict] = {
    "window1": {
        "id": "4",
        "label": "Window",          # Plane window
        "x": 576.69,
        "y": 604.63,
        "width": 713.31,
        "height": 714.69,
        "center": (576.69 + 713.31 / 2, 604.63 + 714.69 / 2),  # (933.345, 961.975)
    },
    "entrance": {
        "id": "2",
        "label": "Entrance",        # Main door / entrance
        "x": 532.61,
        "y": 691.67,
        "width": 898.56,
        "height": 1195.69,
        "center": (532.61 + 898.56 / 2, 691.67 + 1195.69 / 2),  # (981.89, 1289.515)
    },
    "window2": {
        "id": "4",
        "label": "Window",          # Window with BVRIT name
        "x": 555.33,
        "y": 647.98,
        "width": 363.98,
        "height": 361.65,
        "center": (555.33 + 363.98 / 2, 647.98 + 361.65 / 2),   # (737.32, 828.805)
    },
    "idea_labs_entrance": {
        "id": "3",
        "label": "IdeaLabs Entrance",
        "x": 364.75,
        "y": 185.92,
        "width": 442.76,
        "height": 263.94,
        "center": (364.75 + 442.76 / 2, 185.92 + 263.94 / 2),   # (586.13, 317.89)
    },
}


def get_landmark_box(name: str) -> Optional[dict]:
    """Return the bounding-box dict for a named landmark, or None."""
    return LANDMARK_BOXES.get(name)


def landmark_center(name: str) -> Optional[tuple[float, float]]:
    """Return the (cx, cy) center of the bounding box for a landmark."""
    box = get_landmark_box(name)
    return box["center"] if box else None


def landmark_area(name: str) -> Optional[float]:
    """Return the pixel area (width × height) of a landmark bounding box."""
    box = get_landmark_box(name)
    return box["width"] * box["height"] if box else None


def distance_to_landmark_box(point: tuple[float, float], landmark_name: str) -> Optional[float]:
    """
    Euclidean distance from an arbitrary (x, y) point to the
    center of the named landmark's bounding box.
    """
    center = landmark_center(landmark_name)
    if center is None:
        return None
    return math.sqrt((point[0] - center[0]) ** 2 + (point[1] - center[1]) ** 2)


def landmark_summary() -> str:
    """Return a formatted string summarising all registered landmark boxes."""
    lines = ["Registered Landmark Bounding Boxes:", "-" * 40]
    for key, box in LANDMARK_BOXES.items():
        cx, cy = box["center"]
        area = box["width"] * box["height"]
        lines.append(
            f"  {key!r:25s} | label={box['label']!r:20s} | "
            f"x={box['x']:.2f}, y={box['y']:.2f}, "
            f"w={box['width']:.2f}, h={box['height']:.2f} | "
            f"center=({cx:.2f}, {cy:.2f}) | area={area:.0f}px²"
        )
    return "\n".join(lines)


#grid map
class GridMap:

    def __init__(self, json_str: str, floor: int = 1):
        data = json.loads(json_str)
        building = data["building"]
        self.building_name = building["name"]

        floor_data = next(
            f for f in building["floors"] if f["floor_number"] == floor
        )

        #Build node registry
        self.nodes: dict[str, dict] = {}
        self.positions: dict[str, tuple[int, int]] = {}
        for n in floor_data["nodes"]:
            self.nodes[n["id"]] = {
                "name": n["name"],
                "type": n["type"],
            }
            self.positions[n["id"]] = tuple(n["position"])

        #Build bidirectional adjacency list
        self.adjacency: dict[str, list[tuple[str, int]]] = {
            nid: [] for nid in self.nodes
        }
        for e in floor_data["edges"]:
            a, b, d = e["from_id"], e["to_id"], e["distance"]
            self.adjacency[a].append((b, d))
            self.adjacency[b].append((a, d))   # ← bidirectional

        #Landmarks = rooms (non-junctions)
        self.landmarks: list[str] = [
            nid for nid, nd in self.nodes.items() if nd["type"] == "room"
        ]

        self.landmarks_data = floor_data.get("landmarks", [])
        self.landmark_positions = {lm["id"]: tuple(lm["position"]) for lm in self.landmarks_data}
        self.node_visible_landmarks = {n["id"]: n.get("visible_landmarks", []) for n in floor_data["nodes"]}
        self.node_landmark_data = {n["id"]: n.get("landmark_data", []) for n in floor_data["nodes"]}

    def heuristic(self, a: str, b: str) -> float:
        """Euclidean distance heuristic for A*."""
        ax, ay = self.positions[a]
        bx, by = self.positions[b]
        return math.sqrt((ax - bx) ** 2 + (ay - by) ** 2)

    def distance_to_landmark(self, current_pos, landmark_id):
        if landmark_id in self.landmark_positions:
            lx, ly = self.landmark_positions[landmark_id]
            cx, cy = current_pos
            return math.sqrt((cx - lx)**2 + (cy - ly)**2)
        return None

    def get_visible_landmark_names(self, node_id):
        data = self.node_landmark_data.get(node_id, [])
        return [d["landmark"] for d in data]

    def get_turn_instruction(self, visible_names: list[str]) -> Optional[str]:
        """
        Derive a navigation hint from the set of currently-visible landmarks.

        Rules (extended to include the new bounding-box landmarks):
          - Entrance visible               → use as anchor: "Door ahead – keep straight"
          - IdeaLabs Entrance visible      → "IdeaLabs entrance on your left/right – turn accordingly"
          - window1 (Plane Window) visible → "Large window on your right – keep straight"
          - window2 (BVRIT Window) visible → "BVRIT window visible – keep straight"
          - Legacy rules (Door, Pillar, Chair) retained for backward compatibility.
        """
        # --- NEW bounding-box landmark rules ---
        has_entrance      = "Entrance" in visible_names
        has_idealabs_ent  = "IdeaLabs Entrance" in visible_names
        has_window1       = "Window" in visible_names          # covers both window labels
        has_window2       = has_window1                        # same label; differentiated by context

        if has_idealabs_ent:
            return "IdeaLabs entrance visible – turn toward it"
        if has_entrance:
            return "Main entrance visible – keep straight"
        if has_window1:
            return "Window landmark visible – keep straight"

        # --- Legacy rules ---
        has_door   = "Door"   in visible_names
        has_pillar = "Pillar" in visible_names
        has_chair  = "Chair"  in visible_names

        if has_door and not has_pillar and not has_chair:
            return "turn right"
        elif has_pillar and not has_chair:
            return "keep walking"
        elif has_pillar and has_chair:
            return "keep walking"
        elif has_chair and not has_pillar:
            return "turn right"
        else:
            return None

    def node_name(self, nid: str) -> str:
        return self.nodes[nid]["name"]

    # ------------------------------------------------------------------
    # NEW: proximity check against bounding-box landmarks
    # ------------------------------------------------------------------
    def nearby_box_landmarks(
        self,
        node_id: str,
        threshold: float = 300.0,
    ) -> list[tuple[str, float]]:
        """
        Return a list of (landmark_key, distance) pairs for every
        LANDMARK_BOXES entry whose center is within `threshold` pixels
        of the node's map position.

        The node positions live in grid/map space; the landmark boxes
        live in image/pixel space.  If both coordinate systems are
        aligned (same scale / origin) this comparison is direct.
        Adjust `threshold` if the scales differ.
        """
        pos = self.positions.get(node_id)
        if pos is None:
            return []
        result = []
        for key in LANDMARK_BOXES:
            dist = distance_to_landmark_box(pos, key)
            if dist is not None and dist <= threshold:
                result.append((key, dist))
        result.sort(key=lambda t: t[1])
        return result

    def plot_graph(self):
        """
        Visualizes the graph using matplotlib: nodes as colored points,
        edges as lines, and bounding-box landmark centers as magenta
        diamonds.  Saves the plot to 'navigation_graph.png'.
        """
        try:
            import matplotlib.pyplot as plt
            import matplotlib.patches as mpatches
        except ImportError:
            print("matplotlib not installed. Install with: pip install matplotlib")
            return

        fig, ax = plt.subplots(figsize=(12, 9))

        #Plot edges
        for a, neighbors in self.adjacency.items():
            for b, dist in neighbors:
                x1, y1 = self.positions[a]
                x2, y2 = self.positions[b]
                ax.plot([x1, x2], [y1, y2], 'k-', alpha=0.7, linewidth=2)

        # Plot nodes
        for nid, pos in self.positions.items():
            x, y = pos
            node_type = self.nodes[nid]['type']
            if node_type == 'room':
                color = 'red'
                marker = 's'
            else:
                color = 'blue'
                marker = 'o'
            ax.scatter(x, y, c=color, s=200, marker=marker, edgecolors='black', linewidth=1.5)
            ax.text(x, y + 0.3, self.node_name(nid), ha='center', va='bottom',
                    fontsize=7, fontweight='bold')

        # Plot JSON-defined landmarks (green triangles)
        from collections import defaultdict
        landmarks_by_pos = defaultdict(list)
        for lm in self.landmarks_data:
            pos = tuple(lm["position"])
            landmarks_by_pos[pos].append(lm["name"])

        for pos, names in landmarks_by_pos.items():
            x, y = pos
            ax.scatter(x, y, c='green', s=100, marker='^', edgecolors='black', linewidth=1.5)
            for i, name in enumerate(names):
                ax.text(x, y - 0.5 - i * 0.3, name, ha='center', va='top',
                        fontsize=6, fontweight='bold', color='green')

        # ---------------------------------------------------------------
        # NEW: Plot bounding-box landmark centers (magenta diamonds)
        # ---------------------------------------------------------------
        for key, box in LANDMARK_BOXES.items():
            cx, cy = box["center"]
            ax.scatter(cx, cy, c='magenta', s=150, marker='D',
                       edgecolors='black', linewidth=1.2, zorder=5)
            ax.text(cx, cy - 40, f"{key}\n({box['label']})",
                    ha='center', va='top', fontsize=6,
                    color='purple', fontweight='bold')
            # Draw bounding box rectangle
            rect = mpatches.Rectangle(
                (box["x"], box["y"]), box["width"], box["height"],
                linewidth=1, edgecolor='magenta', facecolor='none',
                linestyle='--', alpha=0.6
            )
            ax.add_patch(rect)

        ax.set_aspect('equal')
        ax.set_title(f"{self.building_name} Floor 1 Navigation Graph", fontsize=14)
        ax.set_xlabel("X Coordinate / Pixel X")
        ax.set_ylabel("Y Coordinate / Pixel Y")
        ax.grid(True, alpha=0.3)

        # Legend
        legend_handles = [
            mpatches.Patch(color='red',     label='Room node'),
            mpatches.Patch(color='blue',    label='Junction node'),
            mpatches.Patch(color='green',   label='JSON landmark'),
            mpatches.Patch(color='magenta', label='Bounding-box landmark center'),
        ]
        ax.legend(handles=legend_handles, loc='upper left', fontsize=8)

        plt.tight_layout()
        out_path = os.path.join(script_dir, "navigation_graph.png")
        plt.savefig(out_path, dpi=150, bbox_inches='tight')
        print(f"Navigation graph saved as '{out_path}'")


#A* ALGORITHM
def astar(grid: GridMap, start: str, goal: str) -> Optional[list[str]]:
    """
    Returns the optimal node-id path from start → goal using A*.
    Returns None if no path exists.
    """
    open_heap: list[tuple[float, float, str, list[str]]] = []
    heapq.heappush(open_heap, (0.0, 0.0, start, [start]))

    visited: dict[str, float] = {}

    while open_heap:
        f, g, current, path = heapq.heappop(open_heap)

        if current == goal:
            return path

        if current in visited and visited[current] <= g:
            continue
        visited[current] = g

        for neighbor, edge_cost in grid.adjacency[current]:
            bonus = -0.5 if grid.node_visible_landmarks.get(neighbor, []) else 0
            new_g = g + edge_cost + bonus
            if neighbor in visited and visited[neighbor] <= new_g:
                continue
            h = grid.heuristic(neighbor, goal)
            heapq.heappush(open_heap, (new_g + h, new_g, neighbor, path + [neighbor]))

    return None


#  DIRECTION GENERATOR
def get_vector(grid: GridMap, from_id: str, to_id: str) -> tuple[int, int]:
    fx, fy = grid.positions[from_id]
    tx, ty = grid.positions[to_id]
    return (tx - fx, ty - fy)


def normalize(v: tuple[int, int]) -> tuple[int, int]:
    x, y = v
    if x == 0 and y == 0:
        return (0, 0)
    mag = math.sqrt(x*x + y*y)
    return (round(x / mag), round(y / mag))


def turn_direction(facing: tuple[int, int], new_dir: tuple[int, int]) -> str:
    fx, fy = facing
    nx, ny = new_dir
    cross = fx * ny - fy * nx
    dot   = fx * nx + fy * ny

    if dot > 0 and cross == 0:
        return "straight"
    if dot < 0:
        return "U-turn (turn around)"
    if cross > 0:
        return "left"
    return "right"


def path_to_directions(grid: GridMap, path: list[str]) -> list[str]:
    """
    Converts a node-id path into human-readable directions.
    Now also reports nearby bounding-box landmarks at each node.
    """
    if len(path) < 2:
        return [f"You are already at {grid.node_name(path[0])}."]

    instructions: list[str] = []
    instructions.append(f"Starting at: {grid.node_name(path[0])}")

    # --- Visible JSON landmarks ---
    visible_names = grid.get_visible_landmark_names(path[0])
    if visible_names:
        instructions.append(f"Visible landmarks: {', '.join(visible_names)}")

    distances = []
    for lm_id in grid.node_visible_landmarks.get(path[0], []):
        dist = grid.distance_to_landmark(grid.positions[path[0]], lm_id)
        if dist is not None:
            lm_name = next((lm["name"] for lm in grid.landmarks_data if lm["id"] == lm_id), lm_id)
            distances.append(f"{lm_name}: {dist:.1f} units")
    if distances:
        instructions.append(f"Distances to landmarks: {', '.join(distances)}")

    # --- NEW: nearby bounding-box landmarks ---
    nearby = grid.nearby_box_landmarks(path[0])
    if nearby:
        nb_strs = [f"{k} ({LANDMARK_BOXES[k]['label']}, {d:.0f}px)" for k, d in nearby]
        instructions.append(f"Nearby detected landmarks: {', '.join(nb_strs)}")

    turn_inst = grid.get_turn_instruction(visible_names)
    if turn_inst:
        instructions.append(f"Navigation instruction: {turn_inst}")

    facing = normalize(get_vector(grid, path[0], path[1]))
    accumulated_steps = 0

    def flush(steps: int):
        if steps > 0:
            instructions.append(f"Move forward {steps} square{'s' if steps != 1 else ''}.")

    for i in range(1, len(path)):
        prev_id = path[i - 1]
        curr_id = path[i]

        raw_vec  = get_vector(grid, prev_id, curr_id)
        new_dir  = normalize(raw_vec)
        distance = round(math.sqrt(raw_vec[0]**2 + raw_vec[1]**2))

        turn = turn_direction(facing, new_dir)

        if turn == "straight":
            accumulated_steps += distance
        else:
            flush(accumulated_steps)
            accumulated_steps = distance
            turn_label = {
                "left":                "Turn left.",
                "right":               "Turn right.",
                "U-turn (turn around)":"Turn around (U-turn).",
            }.get(turn, f"Turn {turn}.")
            instructions.append(turn_label)

        facing = new_dir

        node = grid.nodes[curr_id]
        if node["type"] == "room":
            flush(accumulated_steps)
            accumulated_steps = 0
            instructions.append(f"✅ You have arrived at: {grid.node_name(curr_id)}")

            visible_names = grid.get_visible_landmark_names(curr_id)
            if visible_names:
                instructions.append(f"Visible landmarks: {', '.join(visible_names)}")

            distances = []
            for lm_id in grid.node_visible_landmarks.get(curr_id, []):
                dist = grid.distance_to_landmark(grid.positions[curr_id], lm_id)
                if dist is not None:
                    lm_name = next((lm["name"] for lm in grid.landmarks_data if lm["id"] == lm_id), lm_id)
                    distances.append(f"{lm_name}: {dist:.1f} units")
            if distances:
                instructions.append(f"Distances to landmarks: {', '.join(distances)}")

            # NEW: nearby bounding-box landmarks
            nearby = grid.nearby_box_landmarks(curr_id)
            if nearby:
                nb_strs = [f"{k} ({LANDMARK_BOXES[k]['label']}, {d:.0f}px)" for k, d in nearby]
                instructions.append(f"Nearby detected landmarks: {', '.join(nb_strs)}")

            turn_inst = grid.get_turn_instruction(visible_names)
            if turn_inst:
                instructions.append(f"Navigation instruction: {turn_inst}")

        elif node["type"] == "junction" and i < len(path) - 1:
            next_id  = path[i + 1]
            next_raw = get_vector(grid, curr_id, next_id)
            next_dir = normalize(next_raw)
            if next_dir != facing:
                flush(accumulated_steps)
                accumulated_steps = 0
                instructions.append(f"📍 Waypoint: {grid.node_name(curr_id)}")

                # NEW: nearby bounding-box landmarks at junction
                nearby = grid.nearby_box_landmarks(curr_id)
                if nearby:
                    nb_strs = [f"{k} ({LANDMARK_BOXES[k]['label']}, {d:.0f}px)" for k, d in nearby]
                    instructions.append(f"  Nearby landmarks here: {', '.join(nb_strs)}")

    flush(accumulated_steps)
    return instructions


if __name__ == "__main__":
    # Print landmark box summary at startup
    print(landmark_summary())
    print()

    grid = GridMap(MAP_JSON)
    path = astar(grid, "main_entrance", "seminar_hall")
    if path:
        directions = path_to_directions(grid, path)
        print("Path found:")
        for d in directions:
            print(f"  {d}")
    else:
        print("No path found")
    grid.plot_graph()


# LANDMARK-BASED WAYPOINT ROUTING
_instruction_cache: dict[tuple[str, str], list[str]] = {}


def get_directions(grid: GridMap, loc_a: str, dest_b: str) -> list[str]:
    """
    Main public API.  Routes: loc_a → landmark_1 → … → dest_b
    Intermediate landmarks are chosen as the nearest room nodes along
    the A* path.  Fixed instruction segments are cached.
    """
    full_path = astar(grid, loc_a, dest_b)
    if full_path is None:
        return [f"❌ No path found from '{grid.node_name(loc_a)}' to '{grid.node_name(dest_b)}'."]

    waypoints: list[str] = [full_path[0]]
    for nid in full_path[1:-1]:
        if grid.nodes[nid]["type"] == "room":
            waypoints.append(nid)
    waypoints.append(full_path[-1])

    waypoints = [waypoints[i] for i in range(len(waypoints))
                 if i == 0 or waypoints[i] != waypoints[i-1]]

    route_names = " → ".join(grid.node_name(w) for w in waypoints)
    header = [
        "=" * 60,
        f"  ROUTE PLAN",
        f"  {grid.building_name} — Floor 1",
        f"  {route_names}",
        "=" * 60,
    ]

    all_steps: list[str] = []
    for i in range(len(waypoints) - 1):
        seg_start = waypoints[i]
        seg_end   = waypoints[i + 1]
        key = (seg_start, seg_end)

        if key not in _instruction_cache:
            seg_path = astar(grid, seg_start, seg_end)
            if seg_path is None:
                _instruction_cache[key] = [
                    f"❌ No sub-path from {grid.node_name(seg_start)} to {grid.node_name(seg_end)}"
                ]
            else:
                _instruction_cache[key] = path_to_directions(grid, seg_path)

        all_steps.append(f"\n── Segment {i+1}: {grid.node_name(seg_start)} → {grid.node_name(seg_end)} ──")
        all_steps.extend(_instruction_cache[key])

    return header + all_steps


def print_directions(lines: list[str]):
    for line in lines:
        print(line)
    print()


if __name__ == "__main__":
    grid = GridMap(MAP_JSON, floor=1)

    print(f"\n🏢 Building: {grid.building_name}")
    print(f"🗺️  Landmarks: {[grid.node_name(l) for l in grid.landmarks]}\n")

    grid.plot_graph()

    print_directions(get_directions(grid, "main_entrance", "seminar_hall"))
    print_directions(get_directions(grid, "main_entrance", "exit_2"))
    print_directions(get_directions(grid, "main_entrance", "idea_labs"))
    print_directions(get_directions(grid, "idea_labs", "seminar_hall"))
    print_directions(get_directions(grid, "exit_2", "seminar_hall"))
    print_directions(get_directions(grid, "main_entrance", "idea_lab_R1"))