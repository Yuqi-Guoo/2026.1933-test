import matplotlib.pyplot as plt
import numpy as np
from function import *
from matplotlib.legend_handler import HandlerPatch
import matplotlib.patches as mpatches

Is_plot_in_1_row = True

file_path_coordinates = "../../data/Biesinger/111_n100_std"

num_p = [2, 4, 6, 8]
p_index = 0
r = 5
beta = 0.1

if Is_plot_in_1_row:
    fig, axs = plt.subplots(1, 4, figsize=(24, 6))
else:
    fig, axs = plt.subplots(2, 2, figsize=(20, 20))

axs = axs.flatten()

# --- Figure 6: vary p, fix r ---
for p in num_p:
    # print(f"Current value of r: {r}, p_index: {p_index}")

    file_path_solution = f"../../results/visualization/111_n100_std-ZLP-100-100-{p}-{r}-{beta}.out"
    coordinates_and_demands, coordinates_facility, solution_x, solution_y, leader_demand, follower_demand = read_data(file_path_coordinates, file_path_solution)

    if p_index < len(axs):
        ax = axs[p_index]
    else:
        print("Error: p_index out of range.")
        continue

    square = plt.Rectangle((0, 0), 1, 1, linewidth=2, edgecolor='black', facecolor='none')
    ax.add_patch(square)

    # Draw circles for customers (size determined by demand)
    for i in range(len(coordinates_and_demands)):
        coordinates_x = coordinates_and_demands[i][0]
        coordinates_y = coordinates_and_demands[i][1]
        demand = coordinates_and_demands[i][2] / 4
        circle = plt.Circle((coordinates_x, coordinates_y), demand, color='black', fill=False, linewidth=2)
        ax.add_patch(circle)

    # Draw squares for leader's facilities (size by captured demand)
    for i, idx in enumerate(solution_x):
        coordinates_x = coordinates_facility[idx][0]
        coordinates_y = coordinates_facility[idx][1]
        demand_size = leader_demand[i] / 20
        coordinates, radius = calculate_square_coordinates(coordinates_x, coordinates_y, demand_size)
        square = plt.Rectangle(coordinates, radius, radius, edgecolor='red', facecolor='none', linewidth=2)
        ax.add_patch(square)

    # Draw triangles for follower's facilities (size by captured demand)
    for i, idx in enumerate(solution_y):
        coordinates_x = coordinates_facility[idx][0]
        coordinates_y = coordinates_facility[idx][1]
        demand_size = follower_demand[i] / 20
        X1, X2, X3 = generate_triangle_vertices(coordinates_x, coordinates_y, size=demand_size)
        triangle = plt.Polygon([X1, X2, X3], closed=True, edgecolor='blue', facecolor='none', linewidth=2)
        ax.add_patch(triangle)

    # Draw dashed circles for collocated facilities
    overlap_radius = 5
    for idx_x in solution_x:
        if idx_x in solution_y:
            coordinates_x = coordinates_facility[idx_x][0]
            coordinates_y = coordinates_facility[idx_x][1]
            overlap_circle = plt.Circle((coordinates_x, coordinates_y), overlap_radius,
                                       color='purple', fill=False, linewidth=2.5,
                                       linestyle='--')
            ax.add_patch(overlap_circle)

    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.set_aspect('equal', adjustable='box')

    if Is_plot_in_1_row:
        ax.set_xlabel('Horizontal Coordinate', fontsize=18)
        ax.set_ylabel('Vertical Coordinate', fontsize=18)
        ax.tick_params(labelsize=18)
    else:
        ax.set_xlabel('Horizontal Coordinate', fontsize=25)
        ax.set_ylabel('Vertical Coordinate', fontsize=25)
        ax.tick_params(labelsize=20)

    ax.set_facecolor('white')

    if Is_plot_in_1_row:
        ax.text(0.5, -0.2, f'({chr(97+p_index)})  p = {num_p[p_index]}',
            transform=ax.transAxes, fontsize=20, fontweight='bold',
            ha='center', va='top')
    else:
        ax.text(0.5, -0.12, f'({chr(97+p_index)})  p = {num_p[p_index]}',
            transform=ax.transAxes, fontsize=25, fontweight='bold',
            ha='center', va='top')

    p_index += 1


from matplotlib.patches import Rectangle as LegendRectangle
from matplotlib.patches import Polygon as LegendPolygon
from matplotlib.lines import Line2D

if Is_plot_in_1_row:
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='none',
               markeredgecolor='black', markersize=20, linewidth=2, label='Customer zones'),
        Line2D([0], [0], marker='s', color='w', markerfacecolor='none',
               markeredgecolor='red', markersize=20, linewidth=2.5, label="Leader's facility"),
        Line2D([0], [0], marker='^', color='w', markerfacecolor='none',
               markeredgecolor='blue', markersize=20, linewidth=2.5, label="Follower's facility"),
        mpatches.Patch(facecolor='none', edgecolor='purple', linewidth=2.5,
                       linestyle='--', label='Colocation')
    ]
else:
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='none',
               markeredgecolor='black', markersize=25, linewidth=2, label='Customer zones'),
        Line2D([0], [0], marker='s', color='w', markerfacecolor='none',
               markeredgecolor='red', markersize=25, linewidth=2.5, label="Leader's facility"),
        Line2D([0], [0], marker='^', color='w', markerfacecolor='none',
               markeredgecolor='blue', markersize=25, linewidth=2.5, label="Follower's facility"),
        mpatches.Patch(facecolor='none', edgecolor='purple', linewidth=2.5,
                       linestyle='--', label='Colocation')
    ]

# custom handler to render the colocation legend entry as a dashed circle
class HandlerDashedCircle(HandlerPatch):
    def create_artists(self, legend, orig_handle, xdescent, ydescent,
                      width, height, fontsize, trans):
        center = 0.5 * width - 0.5 * xdescent, 0.5 * height - 0.5 * ydescent
        radius = min(width, height) / 1.2
        p = mpatches.Circle(xy=center, radius=radius, facecolor='none',
                           edgecolor=orig_handle.get_edgecolor(),
                           linewidth=orig_handle.get_linewidth(),
                           linestyle=orig_handle.get_linestyle(),
                           transform=trans)
        return [p]

if Is_plot_in_1_row:
    fig.legend(handles=legend_elements, loc='lower center', ncol=4,
          fontsize=25, frameon=False, bbox_to_anchor=(0.5, 0.0),
          handler_map={mpatches.Patch: HandlerDashedCircle()},
          markerscale=1.5, handlelength=2, handletextpad=1)
else:
    fig.legend(handles=legend_elements, loc='lower center', ncol=4,
          fontsize=30, frameon=False, bbox_to_anchor=(0.5, -0.01),
          handler_map={mpatches.Patch: HandlerDashedCircle()},
          markerscale=1.5, handlelength=2, handletextpad=1)

plt.tight_layout(pad=3.0, h_pad=5.0, w_pad=5.0, rect=[0, 0.12, 1, 1])
fig.set_size_inches(23.4, 6.4)

script_dir = os.path.dirname(os.path.abspath(__file__))
output_dir = os.path.join(script_dir, "eps")
png_dir = os.path.join(script_dir, "png")
if not os.path.exists(output_dir):
    os.makedirs(output_dir)
if not os.path.exists(png_dir):
    os.makedirs(png_dir)

if Is_plot_in_1_row:
    output_path_eps = os.path.join(output_dir, "visualization_r5.eps")
    plt.savefig(output_path_eps, format="eps", dpi=300, bbox_inches="tight")
    plt.savefig(os.path.join(png_dir, "visualization_r5.png"), format="png", dpi=150, bbox_inches="tight")
else:
    output_path_eps = os.path.join(output_dir, "visualization_r5.eps")
    plt.savefig(output_path_eps, format="eps", dpi=300, bbox_inches="tight")
    plt.savefig(os.path.join(png_dir, "visualization_r5.png"), format="png", dpi=150, bbox_inches="tight")

print(f"Saved EPS to: {output_dir}")
print(f"Saved PNG to: {png_dir}")
plt.show()


# --- Figure 7: vary r, fix p ---
num_r = [2, 4, 6, 8]
r_index = 0
p = 5
beta = 0.1

if Is_plot_in_1_row:
    fig, axs = plt.subplots(1, 4, figsize=(24, 6))
else:
    fig, axs = plt.subplots(2, 2, figsize=(20, 20))

axs = axs.flatten()

for r in num_r:
    # print(f"Current value of r: {r}, r_index: {r_index}")

    file_path_solution = f"../../results/visualization/111_n100_std-ZLP-100-100-{p}-{r}-{beta}.out"
    coordinates_and_demands, coordinates_facility, solution_x, solution_y, leader_demand, follower_demand = read_data(file_path_coordinates, file_path_solution)

    if r_index < len(axs):
        ax = axs[r_index]
    else:
        print("Error: r_index out of range.")
        continue

    square = plt.Rectangle((0, 0), 1, 1, linewidth=2, edgecolor='black', facecolor='none')
    ax.add_patch(square)

    # Draw circles for customers (size determined by demand)
    for i in range(len(coordinates_and_demands)):
        coordinates_x = coordinates_and_demands[i][0]
        coordinates_y = coordinates_and_demands[i][1]
        demand = coordinates_and_demands[i][2] / 4
        circle = plt.Circle((coordinates_x, coordinates_y), demand, color='black', fill=False, linewidth=2)
        ax.add_patch(circle)

    # Draw squares for leader's facilities (size by captured demand)
    fixed_size = 0.015
    for i, idx in enumerate(solution_x):
        coordinates_x = coordinates_facility[idx][0]
        coordinates_y = coordinates_facility[idx][1]
        demand_size = leader_demand[i] / 20
        coordinates, radius = calculate_square_coordinates(coordinates_x, coordinates_y, demand_size)
        square = plt.Rectangle(coordinates, radius, radius, edgecolor='red', facecolor='none', linewidth=2)
        ax.add_patch(square)

    # Draw triangles for follower's facilities (size by captured demand)
    for i, idx in enumerate(solution_y):
        coordinates_x = coordinates_facility[idx][0]
        coordinates_y = coordinates_facility[idx][1]
        demand_size = follower_demand[i] / 20
        X1, X2, X3 = generate_triangle_vertices(coordinates_x, coordinates_y, size=demand_size)
        triangle = plt.Polygon([X1, X2, X3], closed=True, edgecolor='blue', facecolor='none', linewidth=2)
        ax.add_patch(triangle)

    # Draw dashed circles for collocated facilities
    overlap_radius = 5
    for idx_x in solution_x:
        if idx_x in solution_y:
            coordinates_x = coordinates_facility[idx_x][0]
            coordinates_y = coordinates_facility[idx_x][1]
            overlap_circle = plt.Circle((coordinates_x, coordinates_y), overlap_radius,
                                       color='purple', fill=False, linewidth=2.5,
                                       linestyle='--')
            ax.add_patch(overlap_circle)

    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.set_aspect('equal', adjustable='box')

    if Is_plot_in_1_row:
        ax.set_xlabel('Horizontal Coordinate', fontsize=18)
        ax.set_ylabel('Vertical Coordinate', fontsize=18)
        ax.tick_params(labelsize=18)
    else:
        ax.set_xlabel('Horizontal Coordinate', fontsize=25)
        ax.set_ylabel('Vertical Coordinate', fontsize=25)
        ax.tick_params(labelsize=20)

    ax.set_facecolor('white')

    if Is_plot_in_1_row:
        ax.text(0.5, -0.2, f'({chr(97+r_index)})  r = {num_r[r_index]}',
            transform=ax.transAxes, fontsize=20, fontweight='bold',
            ha='center', va='top')
    else:
        ax.text(0.5, -0.12, f'({chr(97+r_index)})  r = {num_r[r_index]}',
            transform=ax.transAxes, fontsize=25, fontweight='bold',
            ha='center', va='top')

    r_index += 1


if Is_plot_in_1_row:
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='none',
               markeredgecolor='black', markersize=20, linewidth=2, label='Customer zones'),
        Line2D([0], [0], marker='s', color='w', markerfacecolor='none',
               markeredgecolor='red', markersize=20, linewidth=2.5, label="Leader's facility"),
        Line2D([0], [0], marker='^', color='w', markerfacecolor='none',
               markeredgecolor='blue', markersize=20, linewidth=2.5, label="Follower's facility"),
        mpatches.Patch(facecolor='none', edgecolor='purple', linewidth=2.5,
                       linestyle='--', label='Colocation')
    ]
else:
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='none',
               markeredgecolor='black', markersize=25, linewidth=2, label='Customer zones'),
        Line2D([0], [0], marker='s', color='w', markerfacecolor='none',
               markeredgecolor='red', markersize=25, linewidth=2.5, label="Leader's facility"),
        Line2D([0], [0], marker='^', color='w', markerfacecolor='none',
               markeredgecolor='blue', markersize=25, linewidth=2.5, label="Follower's facility"),
        mpatches.Patch(facecolor='none', edgecolor='purple', linewidth=2.5,
                       linestyle='--', label='Colocation')
    ]

if Is_plot_in_1_row:
    fig.legend(handles=legend_elements, loc='lower center', ncol=4,
          fontsize=25, frameon=False, bbox_to_anchor=(0.5, 0.0),
          handler_map={mpatches.Patch: HandlerDashedCircle()},
          markerscale=1.5, handlelength=2, handletextpad=1)
else:
    fig.legend(handles=legend_elements, loc='lower center', ncol=4,
          fontsize=30, frameon=False, bbox_to_anchor=(0.5, -0.01),
          handler_map={mpatches.Patch: HandlerDashedCircle()},
          markerscale=1.5, handlelength=2, handletextpad=1)

plt.tight_layout(pad=3.0, h_pad=5.0, w_pad=5.0, rect=[0, 0.12, 1, 1])
fig.set_size_inches(23.4, 6.4)

if Is_plot_in_1_row:
    output_path_eps = os.path.join(output_dir, "visualization_p5.eps")
    plt.savefig(output_path_eps, format="eps", dpi=300, bbox_inches="tight")
    plt.savefig(os.path.join(png_dir, "visualization_p5.png"), format="png", dpi=150, bbox_inches="tight")
else:
    output_path_eps = os.path.join(output_dir, "visualization_p5.eps")
    plt.savefig(output_path_eps, format="eps", dpi=300, bbox_inches="tight")
    plt.savefig(os.path.join(png_dir, "visualization_p5.png"), format="png", dpi=150, bbox_inches="tight")

print(f"Saved EPS to: {output_dir}")
print(f"Saved PNG to: {png_dir}")
plt.show()
