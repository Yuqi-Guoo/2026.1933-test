import pandas as pd
import re

count = 0
product_ts = 1
num_rows = 0

new_columns = pd.read_csv("scripts/table/Biesinger_EA.csv")

with open("results/Biesinger_summary.out", "r", encoding="utf-8") as f:
    latex_lines = f.readlines()

updated_lines = []
inserted_header = False
data_idx = 0

for line in latex_lines:
    if "&" in line and "\\" in line and len(line.split("&")) >= 4 and re.search(r'\d', line) and data_idx < len(new_columns):
        existing_row = line.strip().split("&")
        obj, sd, ts = new_columns.iloc[data_idx]
        try:
            fifth_column = float(existing_row[4].strip())
            ts = float(ts)
            if abs(fifth_column - float(f" {obj} ")) < 0.01:
                count += 1
            product_ts *= ts
            num_rows += 1
        except ValueError:
            pass
        data_idx += 1
        continue

geometric_mean = product_ts ** (1 / num_rows) if num_rows > 0 else 0

data_idx = 0

for line in latex_lines:
    if "\\begin{tabular}" in line:
        updated_lines.append(line.strip()[:-1] + "rr}\n")
        continue

    if "\\multicolumn{6}{c}{B\\&C+EF}" in line:
        updated_lines.append(line.rstrip() + " & \\multicolumn{2}{c}{EA} \n")
        continue

    if "\\cmidrule(r){17-22}" in line:
        updated_lines.append(line.strip() + " \\cmidrule(r){23-24}\n")
        continue

    if not inserted_header and "\\texttt{T\\,(G\\%)}" in line and "\\texttt{Obj}" in line:
        updated_lines.append(
            "& & & &    \\texttt{Obj}\t& \\texttt{T\\,(G\\%)}\t&    \\texttt{N}\t&   \\texttt{LPG\\%}\t& \\texttt{CT}\t& \\texttt{CN}\t"
            "&    \\texttt{Obj}\t& \\texttt{T\\,(G\\%)}\t&    \\texttt{N}\t&   \\texttt{LPG\\%}\t& \\texttt{CT}\t& \\texttt{CN}\t"
            "&    \\texttt{Obj}\t& \\texttt{T\\,(G\\%)}\t&    \\texttt{N}\t&   \\texttt{LPG\\%}\t& \\texttt{CT}\t& \\texttt{CN}\t"
            "&     \\texttt{Obj}\t& \\texttt{T}\\\\\n"
        )
        inserted_header = True
        continue

    if "\\texttt{Ave.}" in line or "\\texttt{Sol.}" in line:
        existing_row = line.strip().split("&")
        last = existing_row[-1].rstrip()
        if last.endswith("\\\\"):
            last = last[:-2].rstrip()
        elif last.endswith("\\"):
            last = last[:-1].rstrip()
        if "\\texttt{Sol.}" in line and last.strip() == "":
            existing_row = existing_row[:-1]
        else:
            existing_row[-1] = last
        updated_lines.append("&".join(existing_row + ["      ", "      \\\\"]) + "\n")
        continue

    if "&" in line and "\\" in line and len(line.split("&")) >= 4:
        existing_row = line.strip().split("&")
        obj, sd, ts = new_columns.iloc[data_idx]
        last = existing_row[-1].rstrip()
        if last.endswith("\\\\"):
            last = last[:-2].rstrip()
        elif last.endswith("\\"):
            last = last[:-1].rstrip()
        existing_row[-1] = last
        bnc_ef_obj_str = existing_row[16].strip()
        try:
            if float(bnc_ef_obj_str) > float(str(obj).strip()):
                existing_row[16] = f"${{ {bnc_ef_obj_str} }}^*$"
        except ValueError:
            pass
        updated_lines.append("&".join(existing_row + [f" {obj} ", f" {ts}  \\\\"]) + "\n")
        data_idx += 1
    else:
        updated_lines.append(line)

with open("scripts/table/Table1.tex", "w", encoding="utf-8") as f:
    f.writelines(updated_lines)

print("Updated LaTeX table saved to scripts/table/Table1.tex")
