import re
import os
import math

sqrt_2 = math.sqrt(2)

def generate_triangle_vertices(xc, yc, size=0.2):
    x1, y1 = xc - (sqrt_2*size/2), yc - (sqrt_2*size/2)
    x2, y2 = xc + (sqrt_2*size/2), yc - (sqrt_2*size/2)
    x3, y3 = xc, yc + (sqrt_2*size/2)
    return (x1, y1), (x2, y2), (x3, y3)

def calculate_square_coordinates(center_x, center_y, radius):
    half_side = sqrt_2 * radius
    x, y = center_x - (sqrt_2*radius/2), center_y - (sqrt_2*radius/2)
    return (x, y), half_side


def read_data(file_path_coordinates, file_path_solution):
    # parse coordinate file (two formats) and solution file
    coordinates_and_demands = []
    coordinates_facility = []

    with open(file_path_coordinates, 'r') as file:
        content = file.read()

        has_cus_location = 'Cus_location:' in content
        has_facility_location = 'Facility_location:' in content

        if has_cus_location:
            # tagged format: Cus_location:, Facility_location:, Demand:
            coordinates_pattern = r"Cus_location:\s*(-?\d+\.?\d*)\s+(-?\d+\.?\d*)"
            coordinate_matches = re.findall(coordinates_pattern, content)
            coordinates = [(float(x), float(y)) for x, y in coordinate_matches]

            if has_facility_location:
                coordinates_facility_pattern = r"Facility_location:\s*(-?\d+\.?\d*)\s+(-?\d+\.?\d*)"
                coordinate_facility_matches = re.findall(coordinates_facility_pattern, content)
                coordinates_facility = [(float(x), float(y)) for x, y in coordinate_facility_matches]

            demand_pattern = r"Demand:\s*(\d+)"
            demand_matches = re.findall(demand_pattern, content)
            demands = [int(d) for d in demand_matches]

        else:
            # plain format: index x y demand
            lines = content.strip().split('\n')
            coordinates = []
            demands = []

            for line in lines:
                line = line.strip()
                if line.startswith('test_') or line.startswith('Coordinates') or \
                   line.startswith('facilities') or line.startswith('points:') or not line:
                    continue
                parts = line.split()
                if len(parts) >= 4:
                    try:
                        x = float(parts[1])
                        y = float(parts[2])
                        demand = int(parts[3])
                        coordinates.append((x, y))
                        demands.append(demand)
                    except (ValueError, IndexError):
                        continue

            coordinates_facility = coordinates.copy()

        if len(coordinates) == len(demands):
            coordinates_and_demands = [(x, y, demand) for (x, y), demand in zip(coordinates, demands)]
        else:
            print(f"Warning: coordinate count ({len(coordinates)}) != demand count ({len(demands)})")

    # parse solution file
    solution_x = []
    solution_y = []
    leader_demand = []
    follower_demand = []

    with open(file_path_solution, 'r') as file:
        data = file.read()

        match_x = re.findall(r"Solution X:\s*(\[[\d,\s]*\])", data)
        if match_x:
            solution_x = [int(d) - 1 for d in eval(match_x[0])] if match_x[0].strip() != '[]' else []
        else:
            print("Warning: Solution X not found")

        match_y = re.findall(r"Solution Y:\s*(\[[\d,\s]*\])", data)
        if match_y:
            solution_y = [int(d) - 1 for d in eval(match_y[0])] if match_y[0].strip() != '[]' else []
        else:
            print("Warning: Solution Y not found")

        match_leader = re.findall(r'leader_capture_demand:\s*(\[[\d. ,]+\])', data)
        if match_leader:
            leader_demand = [float(d) for d in eval(match_leader[0])]
        else:
            print("Warning: leader_capture_demand not found")
            leader_demand = [0] * len(solution_x)

        match_follower = re.findall(r'follower_capture_demand:\s*(\[[\d. ,]+\])', data)
        if match_follower:
            follower_demand = [float(d) for d in eval(match_follower[0])]
        else:
            print("Warning: follower_capture_demand not found")
            follower_demand = [0] * len(solution_y)

    return coordinates_and_demands, coordinates_facility, solution_x, solution_y, leader_demand, follower_demand
