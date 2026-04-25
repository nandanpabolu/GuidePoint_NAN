"""
navigation.py — ATL Indoor Navigation System
==============================================
Scope:
  1. User inputs start and finish location.
  2. A* algorithm computes the path A → B.
  3. Navigation loop runs:
     3.1  Every 0.5 s, poll get_camera_landmarks() for visible landmarks
          and their bounding-box sizes (width × height in pixels).
     3.2  At each step the system knows which node to reach next and which
          landmark marks the turn.  When the landmark's apparent pixel area
          (from the camera) is >= the reference area stored in the JSON, the
          user is told to turn / proceed to the next step.
  4. Loop continues until the destination is reached.

Coordinate system
-----------------
  - Positions are 2-D vectors (x, y) in grid units.
  - 1 grid unit = 4 walking steps.
  - All positions are stored as tuples so they can be used as dict keys.

Camera interface
----------------
  get_camera_landmarks() is the single hook that must be replaced with a
  real camera / CV pipeline.  It returns a list of dicts:
      [{"landmark": "Door", "width": <px>, "height": <px>}, ...]
  The stub below simulates progressive growth as the user walks closer.
"""

import json
import heapq
import math
import os
import time
from typing import Optional


# JSON MAP LOADING
script_dir = os.path.dirname(os.path.abspath(__file__))
_json_path = os.path.join(script_dir, "ATL_JSON.json")
with open(_json_path) as _f:
    MAP_JSON = _f.read()


# CAMERA INTERFACE  ← replace this stub with real CV output
_sim_poll_count: dict[str, int] = {}


def get_camera_landmarks(from_node_id: str, toward_node_id: str) -> list[dict]:
    key = (from_node_id, toward_node_id)
    _sim_poll_count[key] = _sim_poll_count.get(key, 0) + 1
    polls  = _sim_poll_count[key]
    growth = 1.0 + 0.15 * polls

    grid     = _GLOBAL_GRID
    ref_data = grid.node_landmark_data.get(toward_node_id, [])
    result   = []
    for entry in ref_data:
        result.append({
            "landmark": entry["landmark"],
            "width":    entry["width"]  * growth,
            "height":   entry["height"] * growth,
        })
    return result



# GRID MAP
class GridMap:

    def __init__(self, json_str: str, floor: int = 1):
        data = json.loads(json_str)
        building = data["building"]
        self.building_name: str = building["name"]

        floor_data = next(
            f for f in building["floors"] if f["floor_number"] == floor
        )

        self.nodes: dict[str, dict] = {}
        self.positions: dict[str, tuple[int, int]] = {}
        for n in floor_data["nodes"]:
            self.nodes[n["id"]] = {
                "name":     n["name"],
                "type":     n["type"],
                "position": tuple(n["position"]),
            }
            self.positions[n["id"]] = tuple(n["position"])

        self.adjacency: dict[str, list[tuple[str, int]]] = {
            nid: [] for nid in self.nodes
        }
        for e in floor_data["edges"]:
            a, b, d = e["from_id"], e["to_id"], e["distance"]
            self.adjacency[a].append((b, d))
            self.adjacency[b].append((a, d))

        self.node_landmark_data: dict[str, list[dict]] = {
            n["id"]: n.get("landmark_data", []) for n in floor_data["nodes"]
        }

        self.node_visible_landmarks: dict[str, list[str]] = {
            n["id"]: n.get("visible_landmarks", []) for n in floor_data["nodes"]
        }

        self.landmarks_data: list[dict] = floor_data.get("landmarks", [])
        self.landmark_positions: dict[str, tuple] = {
            lm["id"]: tuple(lm["position"]) for lm in self.landmarks_data
        }

        self.room_nodes: list[str] = [
            nid for nid, nd in self.nodes.items() if nd["type"] == "room"
        ]

    def node_name(self, nid: str) -> str:
        return self.nodes[nid]["name"]

    def heuristic(self, a: str, b: str) -> float:
        ax, ay = self.positions[a]
        bx, by = self.positions[b]
        return math.sqrt((ax - bx) ** 2 + (ay - by) ** 2)

    def get_reference_landmark_size(self, node_id: str, landmark_label: str) -> Optional[float]:
        for entry in self.node_landmark_data.get(node_id, []):
            if entry["landmark"].lower() == landmark_label.lower():
                return entry["width"] * entry["height"]
        return None

    def get_turn_landmark(self, node_id: str) -> Optional[str]:
        priority = ["Door", "Doorway", "Pillar", "Lighting", "Poster", "Window"]

        visible_ids = self.node_visible_landmarks.get(node_id, [])
        if visible_ids:
            id_to_name = {lm["id"]: lm["name"] for lm in self.landmarks_data}
            visible_names = [
                id_to_name[lm_id]
                for lm_id in visible_ids
                if lm_id in id_to_name
            ]
            for p in priority:
                if p in visible_names:
                    return p
            return visible_names[0] if visible_names else None

        data = self.node_landmark_data.get(node_id, [])
        if not data:
            return None
        for p in priority:
            for entry in data:
                if entry["landmark"] == p:
                    return p
        return data[0]["landmark"]



# A* ALGORITHM
def astar(grid: GridMap, start: str, goal: str) -> Optional[list[str]]:
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

        for neighbour, cost in grid.adjacency[current]:
            new_g = g + cost
            if neighbour in visited and visited[neighbour] <= new_g:
                continue
            h = grid.heuristic(neighbour, goal)
            heapq.heappush(open_heap, (new_g + h, new_g, neighbour, path + [neighbour]))

    return None



# DIRECTION HELPERS

def _vec(grid: GridMap, from_id: str, to_id: str) -> tuple[int, int]:
    fx, fy = grid.positions[from_id]
    tx, ty = grid.positions[to_id]
    return (tx - fx, ty - fy)


def _norm(v: tuple[int, int]) -> tuple[int, int]:
    x, y = v
    if x == 0 and y == 0:
        return (0, 0)
    mag = math.sqrt(x * x + y * y)
    return (round(x / mag), round(y / mag))


def _turn_direction(facing: tuple[int, int], new_dir: tuple[int, int]) -> str:
    fx, fy = facing
    nx, ny = new_dir
    cross = fx * ny - fy * nx
    dot   = fx * nx + fy * ny
    if dot > 0 and cross == 0:
        return "straight"
    if dot < 0:
        return "U-turn"
    if cross > 0:
        return "left"
    return "right"


def _steps_label(units: int) -> str:
    steps = units * 4
    return f"{steps} step{'s' if steps != 1 else ''} ({units} unit{'s' if units != 1 else ''})"



# STEP PLAN

class NavigationStep:

    def __init__(
        self,
        node_id: str,
        instruction: str,
        turn_landmark: Optional[str] = None,
        ref_area: Optional[float] = None,
        is_destination: bool = False,
    ):
        self.node_id       = node_id
        self.instruction   = instruction
        self.turn_landmark = turn_landmark
        self.ref_area      = ref_area
        self.is_destination = is_destination

    def __repr__(self) -> str:
        return (
            f"NavigationStep(node={self.node_id!r}, "
            f"instruction={self.instruction!r}, "
            f"landmark={self.turn_landmark!r}, "
            f"ref_area={self.ref_area})"
        )


def build_step_plan(grid: GridMap, path: list[str]) -> list[NavigationStep]:
    if len(path) < 2:
        return [NavigationStep(path[0], f"You are already at {grid.node_name(path[0])}.",
                               is_destination=True)]

    steps: list[NavigationStep] = []
    facing = _norm(_vec(grid, path[0], path[1]))
    accumulated_units = 0

    def flush_walk(toward_id: str, lm: Optional[str], area: Optional[float], dest: bool):
        if accumulated_units > 0:
            steps.append(NavigationStep(
                node_id=toward_id,
                instruction=f"Walk forward {_steps_label(accumulated_units)}.",
                turn_landmark=lm,
                ref_area=area,
                is_destination=dest,
            ))

    for i in range(1, len(path)):
        prev_id = path[i - 1]
        curr_id = path[i]
        raw     = _vec(grid, prev_id, curr_id)
        new_dir = _norm(raw)
        dist    = round(math.sqrt(raw[0] ** 2 + raw[1] ** 2))
        turn    = _turn_direction(facing, new_dir)

        if turn == "straight":
            accumulated_units += dist
        else:
            lm   = grid.get_turn_landmark(curr_id)
            area = grid.get_reference_landmark_size(curr_id, lm) if lm else None
            flush_walk(curr_id, lm, area, False)
            accumulated_units = dist

            turn_label = {
                "left":   "Turn LEFT",
                "right":  "Turn RIGHT",
                "U-turn": "Turn AROUND (U-turn)",
            }.get(turn, f"Turn {turn}")
            steps.append(NavigationStep(
                node_id=curr_id,
                instruction=f"{turn_label} at {grid.node_name(curr_id)}.",
                turn_landmark=lm,
                ref_area=area,
                is_destination=False,
            ))

        facing = new_dir

        is_last = (i == len(path) - 1)
        node    = grid.nodes[curr_id]

        if is_last:
            lm   = grid.get_turn_landmark(curr_id)
            area = grid.get_reference_landmark_size(curr_id, lm) if lm else None
            flush_walk(curr_id, lm, area, True)
            steps.append(NavigationStep(
                node_id=curr_id,
                instruction=f"You have arrived at {grid.node_name(curr_id)}.",
                turn_landmark=lm,
                ref_area=area,
                is_destination=True,
            ))

        elif node["type"] == "junction":
            next_raw = _vec(grid, curr_id, path[i + 1])
            next_dir = _norm(next_raw)
            if next_dir != facing:
                lm   = grid.get_turn_landmark(curr_id)
                area = grid.get_reference_landmark_size(curr_id, lm) if lm else None
                flush_walk(curr_id, lm, area, False)
                accumulated_units = 0

    return steps



# NAVIGATION LOOP

def run_navigation(grid: GridMap, start_id: str, dest_id: str,
                   poll_interval: float = 0.5):

    print(f"\n{grid.building_name}  |  Floor 1")
    print(f"From : {grid.node_name(start_id)}")
    print(f"To   : {grid.node_name(dest_id)}")
    print("─" * 50)

    path = astar(grid, start_id, dest_id)
    if path is None:
        print(f"No path found from '{grid.node_name(start_id)}' "
              f"to '{grid.node_name(dest_id)}'.")
        return

    plan = build_step_plan(grid, path)

    print(f"\nRoute: {' → '.join(grid.node_name(n) for n in path)}")
    print(f"Total steps planned: {len(plan)}\n")

    user_pos: list[float] = list(map(float, grid.positions[start_id]))

    def move_towards(current: list[float], target: tuple, step_size: float = 0.5) -> list[float]:
        dx = target[0] - current[0]
        dy = target[1] - current[1]
        dist = math.sqrt(dx * dx + dy * dy)
        if dist == 0:
            return current
        return [current[0] + (dx / dist) * step_size,
                current[1] + (dy / dist) * step_size]

    current_from_id = start_id

    for step_idx, step in enumerate(plan):
        print(f"\n[Step {step_idx + 1}/{len(plan)}]  {step.instruction}")

        visible_ids = grid.node_visible_landmarks.get(step.node_id, [])
        if visible_ids:
            id_to_name = {lm["id"]: lm["name"] for lm in grid.landmarks_data}
            visible_names = [id_to_name.get(i, i) for i in visible_ids]
            print(f"Expected visible landmarks at {grid.node_name(step.node_id)}: "
                  f"{', '.join(visible_names)}")

        if step.turn_landmark:
            print(f"Watch for: '{step.turn_landmark}'  "
                  f"(trigger when area ≥ 80% of {step.ref_area:.0f} px² "
                  f"= {0.8 * step.ref_area:.0f} px²)")

        if step.is_destination:
            user_pos = list(map(float, grid.positions[step.node_id]))
            print(f"Position vector: {user_pos}")
            break

        triggered = False
        target_pos = grid.positions[step.node_id]

        while not triggered:
            time.sleep(poll_interval)

            user_pos = move_towards(user_pos, target_pos, step_size=0.5)

            camera_data = get_camera_landmarks(current_from_id, step.node_id)

            if step.turn_landmark and step.ref_area is not None:
                trigger_area = 0.8 * step.ref_area
                matched = False
                for det in camera_data:
                    if det["landmark"].lower() == step.turn_landmark.lower():
                        matched = True
                        apparent_area = det["width"] * det["height"]
                        print(f"'{det['landmark']}': area = {apparent_area:.0f} px² "
                              f"(trigger ≥ {trigger_area:.0f} px²)", end="")
                        if apparent_area >= trigger_area:
                            print("TRIGGER — proceed to next step.")
                            triggered = True
                        else:
                            remaining_pct = (trigger_area - apparent_area) / trigger_area * 100
                            print(f"{remaining_pct:.0f}% remaining.")
                            print("Keep walking toward landmark...")
                        break
                if not matched:
                    print(f"'{step.turn_landmark}' not yet in frame — keep walking...")
            else:
                print("No landmark cue. Advancing.")
                triggered = True

        current_from_id = step.node_id
        user_pos = list(map(float, grid.positions[step.node_id]))
        print(f"Position vector: {user_pos}")

    print("\nNavigation complete.\n")



# USER INPUT HELPERS

def _list_nodes(grid: GridMap) -> None:
    print("\nAvailable locations:")
    for nid, nd in grid.nodes.items():
        tag = ""
        print(f"  {tag}  {nid:<20}  {nd['name']}")
    print()


def _prompt_node(grid: GridMap, prompt: str) -> str:
    while True:
        raw = input(prompt).strip().lower().replace(" ", "_")
        if raw in grid.nodes:
            return raw
        matches = [
            nid for nid, nd in grid.nodes.items()
            if raw in nd["name"].lower()
        ]
        if len(matches) == 1:
            print(f"  → Matched '{grid.node_name(matches[0])}'")
            return matches[0]
        elif len(matches) > 1:
            print(f"  Ambiguous — matches: {[grid.node_name(m) for m in matches]}")
        else:
            print(f"'{raw}' not found. Try again.")



# ENTRY POINT

_GLOBAL_GRID: Optional[GridMap] = None


def main():
    global _GLOBAL_GRID

    grid = GridMap(MAP_JSON, floor=1)
    _GLOBAL_GRID = grid

    print("=" * 50)
    print("ATL Indoor Navigation System")
    print("=" * 50)

    _list_nodes(grid)

    start_id = _prompt_node(grid, "Enter START location: ")
    dest_id  = _prompt_node(grid, "Enter DESTINATION   : ")

    if start_id == dest_id:
        print(f"\nYou are already at {grid.node_name(start_id)}.")
        return

    run_navigation(grid, start_id, dest_id, poll_interval=0.5)


if __name__ == "__main__":
    main()