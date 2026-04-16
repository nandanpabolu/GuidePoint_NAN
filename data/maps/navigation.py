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

    def get_turn_instruction(self, visible_names):
        has_l1 = "Door" in visible_names
        has_l2 = "Pillar" in visible_names
        has_l3 = "Chair" in visible_names
        if has_l1 and not has_l2 and not has_l3:
            return "turn right"
        elif has_l2 and not has_l3:
            return "keep walking"
        elif has_l2 and has_l3:
            return "keep walking"
        elif has_l3 and not has_l2:
            return "turn right"
        else:
            return None

    def node_name(self, nid: str) -> str:
        return self.nodes[nid]["name"]

    def plot_graph(self):
        """
        Visualizes the graph using matplotlib: nodes as colored points, edges as lines.
        Saves the plot to 'navigation_graph.png'.
        """
        try:
            import matplotlib.pyplot as plt
        except ImportError:
            print("matplotlib not installed. Install with: pip install matplotlib")
            return

        fig, ax = plt.subplots(figsize=(10, 8))

        #Plot edges
        for a, neighbors in self.adjacency.items():
            for b, dist in neighbors:
                x1, y1 = self.positions[a]
                x2, y2 = self.positions[b]
                ax.plot([x1, x2], [y1, y2], 'k-', alpha=0.7, linewidth=2)  # black lines for edges

        # Plot nodes
        for nid, pos in self.positions.items():
            x, y = pos
            node_type = self.nodes[nid]['type']
            if node_type == 'room':
                color = 'red'
                marker = 's'  # square for rooms
            else:
                color = 'blue'
                marker = 'o'  # circle for junctions
            ax.scatter(x, y, c=color, s=200, marker=marker, edgecolors='black', linewidth=1.5)
            ax.text(x, y + 0.3, self.node_name(nid), ha='center', va='bottom', fontsize=7, fontweight='bold')

        # Plot landmarks
        from collections import defaultdict
        landmarks_by_pos = defaultdict(list)
        for lm in self.landmarks_data:
            pos = tuple(lm["position"])
            landmarks_by_pos[pos].append(lm["name"])
        
        for pos, names in landmarks_by_pos.items():
            x, y = pos
            ax.scatter(x, y, c='green', s=100, marker='^', edgecolors='black', linewidth=1.5)
            for i, name in enumerate(names):
                offset_y = -0.5 - i * 0.3  # stack labels vertically below the marker
                ax.text(x, y + offset_y, name, ha='center', va='top', fontsize=6, fontweight='bold', color='green')

        ax.set_aspect('equal')
        ax.set_title(f"{self.building_name} Floor 1 Navigation Graph", fontsize=14)
        ax.set_xlabel("X Coordinate")
        ax.set_ylabel("Y Coordinate")
        ax.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig(os.path.join(script_dir, "navigation_graph.png"), dpi=150, bbox_inches='tight')
        print("Navigation graph saved as 'navigation_graph.png' in maps folder")


#A* ALGORITHM
def astar(grid: GridMap, start: str, goal: str) -> Optional[list[str]]:
    """
    Returns the optimal node-id path from start → goal using A*.
    Returns None if no path exists.
    """
    # (f_score, g_score, current_node, path_so_far)
    open_heap: list[tuple[float, float, str, list[str]]] = []
    heapq.heappush(open_heap, (0.0, 0.0, start, [start]))

    visited: dict[str, float] = {}   # node → best g_score seen

    while open_heap:
        f, g, current, path = heapq.heappop(open_heap)

        if current == goal:
            return path

        # Skip if we've already found a cheaper route here
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

    return None   # No path found


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
    nx = round(x / mag)
    ny = round(y / mag)
    return (nx, ny)


def turn_direction(facing: tuple[int, int], new_dir: tuple[int, int]) -> str:
    """
    Compute turn relative to current facing direction using 2-D cross product.
      cross > 0 → left turn
      cross < 0 → right turn
      cross = 0 → straight (or U-turn)
    """
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
    Converts a node-id path into human-readable, square-by-square prompts:
      - "Move forward N squares"
      - "Turn left / right / around"
      - "You have arrived at <name>"

    Consecutive segments in the same direction are merged.
    """
    if len(path) < 2:
        return [f"You are already at {grid.node_name(path[0])}."]

    instructions: list[str] = []
    instructions.append(f"Starting at: {grid.node_name(path[0])}")

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
    turn_inst = grid.get_turn_instruction(visible_names)
    if turn_inst:
        instructions.append(f"Navigation instruction: {turn_inst}")

    # Determine initial facing from first segment
    facing = normalize(get_vector(grid, path[0], path[1]))

    # Group consecutive steps by direction, accumulate distance
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
            # Same direction — keep walking
            accumulated_steps += distance
        else:
            # Direction change: flush existing steps first, then turn
            flush(accumulated_steps)
            accumulated_steps = distance
            turn_label = {
                "left":                "Turn left.",
                "right":               "Turn right.",
                "U-turn (turn around)":"Turn around (U-turn).",
            }.get(turn, f"Turn {turn}.")
            instructions.append(turn_label)

        facing = new_dir

        # Label named waypoints (landmarks or notable nodes)
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
            turn_inst = grid.get_turn_instruction(visible_names)
            if turn_inst:
                instructions.append(f"Navigation instruction: {turn_inst}")
        elif node["type"] == "junction" and i < len(path) - 1:
            # Peek ahead — if direction will change, label the junction
            next_id  = path[i + 1]
            next_raw = get_vector(grid, curr_id, next_id)
            next_dir = normalize(next_raw)
            if next_dir != facing:
                flush(accumulated_steps)
                accumulated_steps = 0
                instructions.append(f"📍 Waypoint: {grid.node_name(curr_id)}")

    flush(accumulated_steps)
    return instructions


if __name__ == "__main__":
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
# Cache: (landmark_a, landmark_b) → list[str] instructions
_instruction_cache: dict[tuple[str, str], list[str]] = {}


def get_directions(grid: GridMap, loc_a: str, dest_b: str) -> list[str]:
    """
    get_directions(loc_a, dest_b)

    Main public API.  Routes:
        loc_a → landmark_1 → landmark_2 → … → dest_b

    Intermediate landmarks are chosen as the nearest room nodes
    along the A* path. Fixed instruction segments between any two
    consecutive landmarks are cached so they are computed only once.
    """
    full_path = astar(grid, loc_a, dest_b)
    if full_path is None:
        return [f"❌ No path found from '{grid.node_name(loc_a)}' to '{grid.node_name(dest_b)}'."]

    #Always include start and end; add any room nodes in between.
    waypoints: list[str] = [full_path[0]]
    for nid in full_path[1:-1]:
        if grid.nodes[nid]["type"] == "room":
            waypoints.append(nid)
    waypoints.append(full_path[-1])

    #Remove duplicate consecutive waypoints 
    waypoints = [waypoints[i] for i in range(len(waypoints))
                 if i == 0 or waypoints[i] != waypoints[i-1]]

    #Print high-level route plan 
    route_names = " → ".join(grid.node_name(w) for w in waypoints)
    header = [
        "=" * 60,
        f"  ROUTE PLAN",
        f"  {grid.building_name} — Floor 1",
        f"  {route_names}",
        "=" * 60,
    ]

    #  Collect segment-level instructions (with caching) 
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


#main
def print_directions(lines: list[str]):
    for line in lines:
        print(line)
    print()

if __name__ == "__main__":
    grid = GridMap(MAP_JSON, floor=1)

    print(f"\n🏢 Building: {grid.building_name}")
    print(f"🗺️  Landmarks: {[grid.node_name(l) for l in grid.landmarks]}\n")

    # Generate graph visualization
    grid.plot_graph()

    # Example 1: Main Entrance → Seminar Hall 
    print_directions(
        get_directions(grid, "main_entrance", "seminar_hall")
    )
    #  Example 2: Main Entrance → Exit 2 
    print_directions(
        get_directions(grid, "main_entrance", "exit_2")
    )

    # Example 3: Main Entrance → Idea Labs 
    print_directions(
        get_directions(grid, "main_entrance", "idea_labs")
    )

    # Example 4: Idea Labs → Seminar Hall (cross-building) 
    print_directions(
        get_directions(grid, "idea_labs", "seminar_hall")
    )

    # Example 5: Exit 2 → Seminar Hall 
    print_directions(
        get_directions(grid, "exit_2", "seminar_hall")
    )

    # Example 6: Main Entrance → Idea Lab R1 
    print_directions(
        get_directions(grid, "main_entrance", "idea_lab_R1")
    )
