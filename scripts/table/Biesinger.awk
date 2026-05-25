BEGIN{
    pos = 0
    pos += 1; Col[pos] = "obj"
    pos += 1; Col[pos] = "timeORgap"
    pos += 1; Col[pos] = "node"
    pos += 1; Col[pos] = "rgap"
    pos += 1; Col[pos] = "CutTime"
    pos += 1; Col[pos] = "CutNum"

    str1 = "tex"; str2 = "plain"
    pos += 1; col = "obj";             PrintName[col][str1] = "\\texttt{Obj}";         PrintName[col][str2] = "Obj"
    pos += 1; col = "time";            PrintName[col][str1] = "\\texttt{T}";            PrintName[col][str2] = "T"
    pos += 1; col = "node";            PrintName[col][str1] = "\\texttt{N}";            PrintName[col][str2] = "N"
    pos += 1; col = "gap";             PrintName[col][str1] = "\\texttt{G\\%}";         PrintName[col][str2] = "G(%)"
    pos += 1; col = "rgap";            PrintName[col][str1] = "\\texttt{LPG\\%}";       PrintName[col][str2] = "rG(%)"
    pos += 1; col = "timeORgap";       PrintName[col][str1] = "\\texttt{T\\,(G\\%)}";   PrintName[col][str2] = "T/G"
    pos += 1; col = "PhaseOneTime";    PrintName[col][str1] = "$\\texttt{T}^1$";        PrintName[col][str2] = "T^1"
    pos += 1; col = "PhaseOneBB";      PrintName[col][str1] = "$\\texttt{UB}^1$";       PrintName[col][str2] = "UB^1"
    pos += 1; col = "PhaseOneBInt";    PrintName[col][str1] = "$\\texttt{LB}^1$";       PrintName[col][str2] = "LB^1"
    pos += 1; col = "rCut";            PrintName[col][str1] = "\\texttt{rCut}";         PrintName[col][str2] = "rCut"
    pos += 1; col = "cut_matching,rnum"; PrintName[col][str1] = "";                     PrintName[col][str2] = "rnCM"
    pos += 1; col = "LB";             PrintName[col][str1] = "\\texttt{LB}";            PrintName[col][str2] = "LB"
    pos += 1; col = "CutTime";        PrintName[col][str1] = "\\texttt{CT}";            PrintName[col][str2] = "CT"
    pos += 1; col = "CutNum";         PrintName[col][str1] = "\\texttt{CN}";            PrintName[col][str2] = "CN"
    pos += 1; col = "lp_iter";        PrintName[col][str1] = "\\texttt{ItCnt}";         PrintName[col][str2] = "ItCnt"
    pos += 1; col = "CommonIndex";    PrintName[col][str1] = "\\tblCommonInd";          PrintName[col][str2] = "CommonIndex"
    pos += 1; col = "XYoverlap";      PrintName[col][str1] = "\\tblXYoverlap";          PrintName[col][str2] = "XYoverlap"

    TIMELIMIT = 7200
    limit["time"] = TIMELIMIT
    average = "or"
    if(format ~ /tex/){col_sep = "\t& "; row_sep = "\\\\"; sep = "&"}
    else{format = "plain"; col_sep = "\t"; row_sep = ""}
    prev_m = prev_n = prev_p = prev_r = ""
    length_id = 3
    stopped_in_phase1 = 0
}

function AddName(names, namelist, name) {
    if (names[name] != 1) {
        names[name] = 1
        names[0]++
        namelist[names[0]] = name
    }
}

function compare(names, namelist, sort_type, isnum) {
    for (i = 1; i <= names[0]; i++) {
        for (j = i + 1; j <= names[0]; j++) {
            if (custom_compare(namelist[j], namelist[i], sort_type, isnum) < 0) {
                temp = namelist[i]
                namelist[i] = namelist[j]
                namelist[j] = temp
            }
        }
    }
}

function custom_compare(a, b, sort_type, isnum) {
    if (sort_type == "id") return compare_id_logic(a, b, isnum)
    else if (sort_type == "setting") return compare_setting_logic(a, b)
    return 0
}

function compare_id_logic(a, b, isnum) {
    split(a, partsA, "-")
    split(b, partsB, "-")
    max_parts = (length(partsA) > length(partsB)) ? length(partsA) : length(partsB)
    for (k = 1; k <= max_parts; k++) {
        numA = (k in partsA) ? partsA[k] + 0 : 0
        numB = (k in partsB) ? partsB[k] + 0 : 0
        if (numA != numB) return (numA < numB) ? -1 : 1
    }
    return 0
}

function compare_setting_logic(a, b) {
    return order_setting(a) - order_setting(b)
}

function order_setting(name) {
    if (name == "OldSubmodular") return 1
    else if (name == "NewSubmodular") return 2
    else if (name == "ZLP") return 3
    else return 999
}

function CalculateAverage(_data, _arr_id, _setting, _col, sgmean) {
    startpos = 1
    num = length(_arr_id)
    if (sgmean == 1) {
        average = 1; shift = 1
        for (i = startpos; i <= length(_arr_id); i++) {
            _id = _arr_id[i]
            val = _data[_id][_setting][_col]
            average = average * (shift + val)^(1/num)
        }
        average = average - shift
    }
    if (sgmean == 0) {
        average = 0
        for (i = startpos; i <= length(_arr_id); i++) {
            _id = _arr_id[i]
            val = _data[_id][_setting][_col]
            average = average + val / num
        }
    }
    return average
}

{
    if (FNR == 1) {
        fn = FILENAME
        split(fn, arr_slash_0, "/")
        split(arr_slash_0[length(arr_slash_0)], arr_slash, ".")
        split(arr_slash[1], arr_slash, "-")
        setting = arr_slash[2]
        m = arr_slash[3]
        n = arr_slash[4]
        p = arr_slash[5]
        r = arr_slash[6]
        {
            id = m"-"n"-"p"-"r
            AddName(Ns, Arr_N, n)
            AddName(Ms, Arr_M, m)
            AddName(Ps, Arr_P, p)
            AddName(Qs, Arr_R, r)
            AddName(SCs, Arr_SC, SC)
            AddName(Ids, Arr_id, id)
            AddName(Settings, Arr_setting, setting)
        }
    }
}

/^iter/{
    if ($4 == "UB") {
        if ($10 > TIMELIMIT - 0.01)
            data[id][setting]["PhaseOneTime"] = TIMELIMIT
        else
            data[id][setting]["PhaseOneTime"] = $8
        data[id][setting]["PhaseOneBB"] = $5
        data[id][setting]["PhaseOneBInt"] = $7
    }
}

/Stopped in pahse one/ { data[id][setting]["stopped_in_phase1"] = 1 }
/two_stage/            { data[id][setting]["is_two_stage"] = $2 }
/ItCnt:/               { data[id][setting]["lp_iter"] = $2 }
/Current gap:/         { data[id][setting]["gap"] = $3 }
/Termination Status:/  { data[id][setting]["tstatus"] = $3 }
/Primal Status:/       { data[id][setting]["pstatus"] = $3 }
/Solve Time:/ {
    data[id][setting]["time"] = $3 + data[id][setting]["PhaseOneTime"]
    if (data[id][setting]["time"] > TIMELIMIT - 0.01) data[id][setting]["time"] = TIMELIMIT
}
/Objective Value:/     { data[id][setting]["obj"] = $3 }
/Number of Nodes:/     { data[id][setting]["node"] = $4 }
/Root Best Bound/      { data[id][setting]["rBB"] = $4 }
/Root Best Integer/    { data[id][setting]["rBInt"] = $4 }
/Best Integer/         { data[id][setting]["BInt"] = $3 }


$1 == setting {
    nphaseone = $3;  tphaseone = $5
    nrLazyCut = $7;  trLazyCut = $9
    nrUserCut = $11; trUserCut = $13
    nsLazyCut = $15; tsLazyCut = $17
    nsUserCut = $19; tsUserCut = $21
    data[id][setting]["CutTime"] = trLazyCut + tsLazyCut + trUserCut + tsUserCut + tphaseone
    data[id][setting]["CutNum"]  = nrLazyCut + nsLazyCut + nrUserCut + nsUserCut + nphaseone
}

/Number of common facilities:/ { data[id][setting]["CommonIndex"] = $5 }
/Overlap Coefficient:/         { data[id][setting]["XYoverlap"] = $3 }

/^Best Integer:/ {
    if (stopped_in_phase1 == 1 || data[id][setting]["is_two_stage"] == "false")
        data[id][setting]["rgap"] = (data[id][setting]["rBB"] - data[id][setting]["obj"]) / data[id][setting]["obj"] * 100
}

function format_print(col, val, sep, is_compact) {
    format == "tex" ? str_percent = "\\%" : str_percent = "%"
    if (is_compact == 1) {
        if (col ~ /time/ || col ~ /Time/) printf("%s%.1f", sep, val)
        else if (col ~ /gap/)            printf("%s%.1f", sep, val)
        else if (col ~ /node/)           printf("%s%d", sep, val)
        else if (col ~ /obj/ || col ~ /BB/ || col ~ /LB/ || col ~ /UB/ || col ~ /BInt/) printf("%s%6.3f", sep, val)
        else                             printf("%s%s", sep, val)
    } else {
        if (col ~ /time/ || col ~ /Time/) printf("%s%8.1f", sep, val)
        else if (col ~ /gap/)             printf("%s%7.1f", sep, val)
        else if (col ~ /node/)            printf("%s%d", sep, val)
        else if (col ~ /obj/ || col ~ /BB/ || col ~ /LB/ || col ~ /UB/ || col ~ /BInt/) printf("%s%6.3f", sep, val)
        else                              printf("%s%8s", sep, val)
    }
}

END {
    compare(Ids, Arr_id, "id", 0)
    compare(Settings, Arr_setting, "setting", 0)

    if (format == "tex") {
        printf("\\resizebox{\\textwidth}{!}{\n")
        printf("\\begin{tabular}{lrrr")
        for (ind_setting = 1; ind_setting <= length(Arr_setting); ind_setting++)
            for (ind_col = 1; ind_col <= length(Col); ind_col++)
                printf("r")
        printf("}\n")
        printf("\\toprule\n")
        printf(" \\multicolumn{1}{c}{\\multirow{2}{*}{m}}\n")
        printf("& \\multicolumn{1}{c}{\\multirow{2}{*}{n}}\n")
        printf("& \\multicolumn{1}{c}{\\multirow{2}{*}{p}}\n")
        printf("& \\multicolumn{1}{c}{\\multirow{2}{*}{r}}\n")
        for (ind_setting = 1; ind_setting <= length(Arr_setting); ind_setting++) {
            setting = Arr_setting[ind_setting]
            if (setting == 0) continue
            if (setting == "OldSubmodular")      display = "B\\&C+SF"
            else if (setting == "NewSubmodular") display = "B\\&C+GSF"
            else if (setting == "ZLP")           display = "B\\&C+EF"
            else                                 display = setting
            printf("%s\\multicolumn{%d}{c}{%s}\n", col_sep, length(Col), display)
        }
        printf("%s\n", row_sep)
        tmppos = 1
        for (ind_setting = 1; ind_setting <= length(Arr_setting); ind_setting++) {
            setting = Arr_setting[ind_setting]
            if (setting == 0) continue
            printf("\\cmidrule(r){%d-%d}\n", tmppos+1+length_id, tmppos+length(Col)+length_id)
            tmppos += length(Col)
        }
    } else {
        printf("%20s", "")
        for (ind_setting = 1; ind_setting <= length(Arr_setting); ind_setting++) {
            setting = Arr_setting[ind_setting]
            if (setting == 0) continue
            for (ind_col = 1; ind_col <= length(Col) / 2 - 1; ind_col++)
                printf("\t%8s", "")
            printf("%s", setting)
            for (ind_col = length(Col) / 2; ind_col <= length(Col); ind_col++)
                printf("\t%8s", "")
        }
        printf("\n")
    }

    if (format == "tex") printf("%-20s", "")
    else printf("%-20s", "N-p-q-SC")
    printf("& & &")
    for (ind_setting = 1; ind_setting <= length(Arr_setting); ind_setting++) {
        setting = Arr_setting[ind_setting]
        if (setting == 0) continue
        for (ind_col = 1; ind_col <= length(Col); ind_col++) {
            col = Col[ind_col]
            printf("%s%8s", col_sep, PrintName[col][format])
        }
    }
    printf("%s\n", row_sep)
    printf("\\midrule\n")

    for (ind_id = 1; ind_id <= length(Arr_id); ind_id++) {
        id = Arr_id[ind_id]
        flag_or = 0; flag_and = 1
        if (Ids[id] == "") continue

        split(id, curr_parts, "-")
        curr_m = curr_parts[1]
        curr_n = curr_parts[2]
        curr_p = curr_parts[3]
        curr_r = curr_parts[4]

        id_part = ""
        if (curr_m == "200") continue

        if (curr_m == prev_m) id_part = sep
        else { id_part = curr_m sep; prev_m = curr_m }

        if (curr_n == prev_n && curr_m == prev_m) id_part = id_part sep
        else { id_part = id_part curr_n sep; prev_n = curr_n }

        if (curr_p == prev_p && curr_n == prev_n && curr_m == prev_m) id_part = id_part sep
        else { id_part = id_part curr_p sep; prev_p = curr_p }

        if (curr_r == prev_r && curr_p == prev_p && curr_n == prev_n && curr_m == prev_m) id_part = id_part sep
        else { id_part = id_part curr_r; prev_r = curr_r }

        printf("%-20s", id_part)

        for (ind_setting = 1; ind_setting <= length(Arr_setting); ind_setting++) {
            setting = Arr_setting[ind_setting]
            if (setting == "") continue
            for (ind_col = 1; ind_col <= length(Col); ind_col++) {
                col = Col[ind_col]
                flag_print = 1
                if (col ~ /OR/) {
                    split(col, arr_or, "OR")
                    col1 = arr_or[1]; col2 = arr_or[2]
                    val1 = data[id][setting][col1]; val2 = data[id][setting][col2]
                    col = col1; val = val1
                    if (val1 > limit[col1] - 0.01) {
                        val = val2; col = col2
                        if (col1 == "time") flag_and = 0
                        printf("%s (%.1f)", sep, val)
                    } else {
                        if (col1 == "time") { flag_or = 1; NSol[setting] += 1 }
                        printf("%s%.1f", sep, val)
                    }
                } else if (col ~ /rgap/ && data[id][setting]["time"] > TIMELIMIT - 0.01) {
                    if (setting == "OldSubmodular")
                        data[id][setting]["rgap"] = (data[id][setting]["rBB"] - data[id]["NewSubmodular"]["obj"]) / data[id][setting]["rBB"] * 100
                    val = data[id][setting]["rgap"]
                    if (val < 0.1) printf("%s$<0.1$", col_sep)
                    else           printf("%s%.1f", col_sep, val)
                } else if (col ~ /rgap/ && data[id][setting]["time"] < TIMELIMIT - 0.01) {
                    val = data[id][setting]["rgap"]
                    if (val < 0.1) printf("%s$<0.1$", col_sep)
                    else           printf("%s%.1f", col_sep, val)
                } else {
                    val = data[id][setting][col]
                    if (val == "") { printf("%s%8s", col_sep, "--"); flag_print = 0 }
                    if (col == "time") {
                        if (val == "" || val > TIMELIMIT - 0.01) { flag_and = 0; data[id][setting][col] = TIMELIMIT }
                        else { flag_or = 1; NSol[setting] += 1 }
                    }
                    if (flag_print == 1) format_print(col, val, col_sep, 0)
                }
            }
            if (setting ~ /MO0/) rBB_MO0 = data[id][setting]["rBB"]
            if (setting ~ /MO1/) rBB_MO1 = data[id][setting]["rBB"]
            if (setting ~ /MO1/) obj_MO1  = data[id][setting]["obj"]
        }
        printf("%s\n", row_sep)
        if (flag_or == 1) AddName(AveIds, Arr_id_ave, id)
    }

    format == "tex" ? str_ave = "\\texttt{Ave.}" : str_ave = "Ave."
    printf("%-15s", str_ave)
    printf("& & &")
    for (ind_setting = 1; ind_setting <= length(Arr_setting); ind_setting++) {
        setting = Arr_setting[ind_setting]
        if (setting == 0) continue
        for (ind_col = 1; ind_col <= length(Col); ind_col++) {
            col = Col[ind_col]
            if (col ~ /OR/) {
                split(col, arr_or, "OR")
                printf("%s", col_sep)
                col1 = arr_or[1]
                ind_or = 1
                tmpcol = arr_or[ind_or]; val = CalculateAverage(data, Arr_id_ave, setting, tmpcol, 0)
                format_print(tmpcol, val, "", 1)
            } else if (col ~ /obj/ || col ~ /status/) {
                printf("%s%8s", col_sep, "")
                continue
            } else if (col ~ /node/) {
                val = CalculateAverage(data, Arr_id_ave, setting, col, 0)
                printf("%s%.1f", sep, val)
            } else if (col ~ /CutTime/) {
                val = CalculateAverage(data, Arr_id_ave, setting, col, 0)
                format_print(col, val, col_sep, 0)
            } else if (col ~ /CutNum/) {
                val = CalculateAverage(data, Arr_id_ave, setting, col, 0)
                printf("%s%.1f", col_sep, val)
            } else if (col ~ /rgap/) {
                val = CalculateAverage(data, Arr_id_ave, setting, col, 0)
                if (val < 0.1) printf("%s$<0.1$", col_sep)
                else           printf("%s%.1f", col_sep, val)
            } else {
                printf("%s", sep)
            }
        }
    }
    printf("%s\n", row_sep)
    format == "tex" ? str_nsol = "\\texttt{Sol.}" : str_nsol = "Sol."
    printf("%-15s", str_nsol)
    printf("& & &")
    for (ind_setting = 1; ind_setting <= length(Arr_setting); ind_setting++) {
        setting = Arr_setting[ind_setting]
        printf("%s%8d", col_sep, NSol[setting])
        for (ind_col = 2; ind_col <= length(Col); ind_col++)
            printf("%s%8s", col_sep, "")
    }
    printf("%s\n", row_sep)
    printf("\\bottomrule\n")
    if (format == "tex") { printf("\\end{tabular}\n"); printf("}\n") }
}
