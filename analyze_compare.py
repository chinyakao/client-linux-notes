import sys, os
import pandas as pd

def load_run(run_dir):
    tz = pd.read_csv(os.path.join(run_dir, "thermal_zones.csv"))
    cd = pd.read_csv(os.path.join(run_dir, "cooling_devices.csv"))
    cf = pd.read_csv(os.path.join(run_dir, "cpufreq.csv"))
    # parse time as datetime
    for df in (tz, cd, cf):
        df["time"] = pd.to_datetime(df["time"])
    return tz, cd, cf

def summarize(run_dir):
    tz, cd, cf = load_run(run_dir)
    out = []
    # hottest zone (max temp)
    temp_cols = [c for c in tz.columns if c.endswith("_temp_mC") and "trip" not in c]
    hottest = tz[temp_cols].max().sort_values(ascending=False).head(3)
    out.append(("top_temps_mC", hottest.to_dict()))

    # cooling activity
    cur_cols = [c for c in cd.columns if c.endswith("_cur")]
    max_cols = [c for c in cd.columns if c.endswith("_max")]
    peak_cur = cd[cur_cols].max().sort_values(ascending=False).head(10)
    out.append(("peak_cooling_cur", peak_cur.to_dict()))

    # cpufreq behavior: overall min cur_khz during sustain (rough)
    min_cur = cf["cur_khz"].replace("NA", pd.NA).dropna().astype(float).min()
    out.append(("min_cpufreq_cur_khz", float(min_cur) if pd.notna(min_cur) else None))
    return out

def main(a, b=None):
    print(f"=== Summary: {a} ===")
    for k,v in summarize(a):
        print(k, ":", v)
    if b:
        print(f"\n=== Summary: {b} ===")
        for k,v in summarize(b):
            print(k, ":", v)

        # Quick diff hints
        print("\n=== Quick Compare Hints ===")
        a_tz, a_cd, _ = load_run(a)
        b_tz, b_cd, _ = load_run(b)
        a_max = a_tz.filter(like="_temp_mC").filter(regex=r"^(?!.*trip).*$").max().max()
        b_max = b_tz.filter(like="_temp_mC").filter(regex=r"^(?!.*trip).*$").max().max()
        print(f"Max temp (mC): A={a_max} B={b_max}")
        a_peak = a_cd.filter(like="_cur").max().max()
        b_peak = b_cd.filter(like="_cur").max().max()
        print(f"Peak cooling cur_state: A={a_peak} B={b_peak}")

if __name__ == "__main__":
    if len(sys.argv) not in (2,3):
        print("Usage: python3 analyze_compare.py <runA_dir> [runB_dir]")
        sys.exit(1)
    main(*sys.argv[1:])
