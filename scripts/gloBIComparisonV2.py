import os
import sys
import warnings

import numpy as np
import pandas as pd
import geopandas as gpd
import rasterio
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import seaborn as sns
from rasterio.sample import sample_gen
from scipy import stats
from sklearn.metrics import roc_curve, roc_auc_score

warnings.filterwarnings("ignore")
sns.set_theme(style="whitegrid", palette="muted")

inputs = biab_inputs() if 'biab_inputs' in globals() else {}
output_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp"
os.makedirs(output_dir, exist_ok=True)

def safe_error(message: str):
    print(f"ERROR: {message}", file=sys.stderr, flush=True)
    if 'biab_error_stop' in globals(): biab_error_stop(message)
    elif 'biab_error' in globals(): biab_error(message)
    else: sys.exit(1)

parquet_path = inputs.get("pollen_parquet")
raster_path = inputs.get("pollinator_raster")
high_value_threshold = float(inputs.get("high_value_threshold", 0.6))
 
if not parquet_path or not os.path.exists(parquet_path):
    safe_error(f"pollen_parquet not found: {parquet_path}")
if not raster_path or not os.path.exists(raster_path):
    safe_error(f"pollinator_raster not found: {raster_path}")

print("Loading and normalizing raster data", flush=True)
df = pd.read_parquet(parquet_path)
df = df.dropna(subset=["decimalLatitude", "decimalLongitude", "subScientificName"])
 
with rasterio.open(raster_path) as src:
    raster_bounds = src.bounds
    raster_data = src.read(1).astype(float)
    raster_nodata = src.nodata
    raster_shape = raster_data.shape
    raster_profile= src.profile.copy()
 
if raster_nodata is not None:
    raster_data[raster_data == raster_nodata] = np.nan

valid_mask = ~np.isnan(raster_data)
r_min = float(np.nanmin(raster_data)) if valid_mask.any() else 0.0
r_max = float(np.nanmax(raster_data)) if valid_mask.any() else 1.0

print(f"Original ARIES range: [{r_min:.4f}, {r_max:.4f}]", flush=True)

if r_max > r_min:
    raster_data = (raster_data - r_min) / (r_max - r_min)
elif valid_mask.any():
    raster_data[valid_mask] = 0.0

def normalize_val(val):
    if val == raster_nodata or pd.isna(val):
        return np.nan
    return (float(val) - r_min) / (r_max - r_min) if r_max > r_min else 0.0
 
# Clip GloBI incidences to raster extent
df = df[
    (df.decimalLongitude >= raster_bounds.left)  &
    (df.decimalLongitude <= raster_bounds.right) &
    (df.decimalLatitude  >= raster_bounds.bottom) &
    (df.decimalLatitude  <= raster_bounds.top)
]
print(f"GloBI incidences in raster extent: {len(df):,}", flush=True)
 
if len(df) == 0:
    safe_error(
        f"No GloBI incidences overlap with raster extent {raster_bounds}."
    )
 
gdf = gpd.GeoDataFrame(
    df,
    geometry=gpd.points_from_xy(df.decimalLongitude, df.decimalLatitude),
    crs="EPSG:4326"
)

print("Extracting ARIES values at GloBI incidence points.", flush=True)
with rasterio.open(raster_path) as src:
    coords = [(g.x, g.y) for g in gdf.geometry]
    raw_aries_values = [v[0] for v in sample_gen(src, coords)]
 
#Apply same normalization bounds to the extracted points
gdf["aries_value"] = [normalize_val(v) for v in raw_aries_values]
valid = gdf["aries_value"].notna()
print(f"Valid ARIES extractions: {valid.sum():,}", flush=True)
 
# Save results CSV
csv_path = os.path.join(output_dir, "spatial_comparison_results.csv")
gdf.drop(columns="geometry").to_csv(csv_path, index=False)

print("Running correlation analysis.", flush=True)
n_bins = 30
lons = np.linspace(raster_bounds.left, raster_bounds.right, n_bins + 1)
lats = np.linspace(raster_bounds.bottom, raster_bounds.top,  n_bins + 1)
 
aries_grid = np.full((n_bins, n_bins), np.nan)
gloBI_counts = np.zeros((n_bins, n_bins))
 
for i in range(n_bins):
    for j in range(n_bins):
        mask = (
            (gdf.decimalLongitude >= lons[j]) & (gdf.decimalLongitude < lons[j+1]) &
            (gdf.decimalLatitude  >= lats[i]) & (gdf.decimalLatitude  < lats[i+1])
        )
        gloBI_counts[i, j] = mask.sum()
        cx, cy = (lons[j] + lons[j+1]) / 2, (lats[i] + lats[i+1]) / 2
        try:
            with rasterio.open(raster_path) as src:
                val = list(sample_gen(src, [(cx, cy)]))[0][0]
                if raster_nodata is None or val != raster_nodata:
                    aries_grid[i, j] = normalize_val(val) # Normalized!
        except Exception:
            pass
 
flat_aries  = aries_grid.flatten()
flat_counts = gloBI_counts.flatten()
vm = ~np.isnan(flat_aries)
spearman_r, spearman_p = stats.spearmanr(flat_aries[vm], flat_counts[vm])
pearson_r,  pearson_p  = stats.pearsonr(flat_aries[vm],  flat_counts[vm])
print(f"Spearman r={spearman_r:.4f} p={spearman_p:.4e}", flush=True)
print(f"Pearson  r={pearson_r:.4f}  p={pearson_p:.4e}", flush=True)
 
fig, axes = plt.subplots(1, 2, figsize=(14, 5))
axes[0].scatter(flat_aries[vm], flat_counts[vm], alpha=0.4, s=20, color="#1D9E75")
m, b = np.polyfit(flat_aries[vm], flat_counts[vm], 1)
xl = np.linspace(flat_aries[vm].min(), flat_aries[vm].max(), 100)
axes[0].plot(xl, m * xl + b, color="#0F6E56", linewidth=2)
axes[0].set_xlabel("ARIES pollinator occurrence value (Normalized)")
axes[0].set_ylabel("GloBI incidence count per grid cell")
axes[0].set_title(f"ARIES value vs. GloBI density\nSpearman r={spearman_r:.3f}, p={spearman_p:.3e}")
h = axes[1].hist2d(flat_aries[vm], flat_counts[vm], bins=20, cmap="YlOrRd")
plt.colorbar(h[3], ax=axes[1], label="Cell count")
axes[1].set_xlabel("ARIES value (Normalized)"); axes[1].set_ylabel("GloBI count")
axes[1].set_title("2D density: ARIES vs. GloBI")
plt.tight_layout()
plot_corr = os.path.join(output_dir, "correlation_analysis.png")
plt.savefig(plot_corr, dpi=150, bbox_inches="tight"); plt.close()

print("Running sampling bias analysis.", flush=True)
gdf_valid = gdf[valid].copy()
 
gdf_valid["aries_bin"] = pd.cut(
    gdf_valid["aries_value"],
    bins=[0, 0.2, 0.4, 0.6, 0.8, 1.0],
    labels=["0–0.2", "0.2–0.4", "0.4–0.6", "0.6–0.8", "0.8–1.0"]
)
bin_counts = gdf_valid.groupby("aries_bin", observed=True).size().reset_index(name="count")
 
fig, axes = plt.subplots(1, 2, figsize=(14, 5))
axes[0].bar(bin_counts["aries_bin"], bin_counts["count"], color="#3B8BD4", edgecolor="white")
axes[0].set_xlabel("ARIES bin (Normalized)"); axes[0].set_ylabel("GloBI incidences")
axes[0].set_title("GloBI incidences per ARIES bin\n(sampling bias check)")
plt.tight_layout()
plot_bias = os.path.join(output_dir, "sampling_bias.png")
plt.savefig(plot_bias, dpi=150, bbox_inches="tight"); plt.close()

print("Running gap analysis.", flush=True)
high_value_mask = raster_data > high_value_threshold
observed_mask   = np.zeros_like(raster_data, dtype=bool)
 
with rasterio.open(raster_path) as src:
    for _, row in gdf.iterrows():
        try:
            r, c = src.index(row.decimalLongitude, row.decimalLatitude)
            if 0 <= r < raster_shape[0] and 0 <= c < raster_shape[1]:
                observed_mask[r, c] = True
        except Exception:
            pass
 
gap_mask = high_value_mask & ~observed_mask
gap_raster = np.zeros_like(raster_data)
gap_raster[gap_mask] = 1
 
n_gap = gap_mask.sum()
n_high = high_value_mask.sum()
gap_pct = 100 * n_gap / n_high if n_high > 0 else 0
print(f"High-value cells: {n_high:,}  Gap cells: {n_gap:,} ({gap_pct:.1f}%)", flush=True)
 
gap_raster_path = os.path.join(output_dir, "gap_analysis.tif")
raster_profile.update(dtype=rasterio.uint8, nodata=255)
with rasterio.open(gap_raster_path, "w", **raster_profile) as dst:
    out = gap_raster.astype(np.uint8)
    out[np.isnan(raster_data)] = 255
    dst.write(out, 1)
 
fig, axes = plt.subplots(1, 3, figsize=(18, 5))
ext = [raster_bounds.left, raster_bounds.right, raster_bounds.bottom, raster_bounds.top]
im0 = axes[0].imshow(raster_data, cmap="YlOrRd", origin="upper", extent=ext)
plt.colorbar(im0, ax=axes[0], label="ARIES value (Normalized)")
axes[0].set_title("ARIES pollinator occurrence")
axes[0].set_xlabel("Longitude"); axes[0].set_ylabel("Latitude")
 
axes[1].imshow(raster_data, cmap="Greys", alpha=0.4, origin="upper", extent=ext)
axes[1].scatter(gdf.decimalLongitude, gdf.decimalLatitude, s=1, alpha=0.3, color="#1D9E75")
axes[1].set_title("GloBI observations on raster")
axes[1].set_xlabel("Longitude"); axes[1].set_ylabel("Latitude")
 
cmap_gap = mcolors.ListedColormap(["#f0f0f0", "#E24B4A"])
im2 = axes[2].imshow(gap_raster, cmap=cmap_gap, origin="upper", extent=ext, vmin=0, vmax=1)
cbar2 = plt.colorbar(im2, ax=axes[2], ticks=[0.25, 0.75])
cbar2.ax.set_yticklabels(["observed/low", "gap"])
axes[2].set_title(f"Gap analysis\n{gap_pct:.1f}% of high-value cells unsampled")
axes[2].set_xlabel("Longitude"); axes[2].set_ylabel("Latitude")
plt.tight_layout()
plot_gap = os.path.join(output_dir, "gap_analysis.png")
plt.savefig(plot_gap, dpi=150, bbox_inches="tight"); plt.close()

print("Running taxonomic breakdown.", flush=True)
tax_col = "subOrder" if "subOrder" in gdf_valid.columns else "subScientificName"
if tax_col == "subScientificName":
    gdf_valid = gdf_valid.copy()
    gdf_valid[tax_col] = gdf_valid[tax_col].str.split().str[0]
 
top_groups = gdf_valid[tax_col].value_counts().head(8).index.tolist()
gdf_top    = gdf_valid[gdf_valid[tax_col].isin(top_groups)]
 
tax_stats = []
for group, sub in gdf_top.groupby(tax_col):
    if len(sub) >= 5:
        tax_stats.append({
            "group": group,
            "n": len(sub),
            "mean_aries": sub["aries_value"].mean(),
            "median_aries": sub["aries_value"].median(),
            "std_aries": sub["aries_value"].std(),
        })
tax_df = pd.DataFrame(tax_stats).sort_values("mean_aries", ascending=False)
 
order = tax_df["group"].tolist()
plot_data = [gdf_top.loc[gdf_top[tax_col] == g, "aries_value"].values for g in order]
fig, axes = plt.subplots(1, 2, figsize=(16, 6))
axes[0].barh(order, tax_df["mean_aries"], xerr=tax_df["std_aries"],
             color="#534AB7", alpha=0.8, capsize=4)
axes[0].set_xlabel("Mean ARIES value (Normalized)")
axes[0].set_title("Mean ARIES value by taxonomic group")
axes[0].invert_yaxis()
bp = axes[1].boxplot(plot_data, labels=order, vert=False, patch_artist=True)
colors = plt.cm.Set2(np.linspace(0, 1, len(order)))
for patch, color in zip(bp["boxes"], colors):
    patch.set_facecolor(color)
axes[1].set_xlabel("ARIES value (Normalized)")
axes[1].set_title("Distribution of ARIES values by taxonomic group")
plt.tight_layout()
plot_tax = os.path.join(output_dir, "taxonomic_breakdown.png")
plt.savefig(plot_tax, dpi=150, bbox_inches="tight"); plt.close()

print("Running ROC.", flush=True)
presence_vals = gdf_valid["aries_value"].dropna().tolist()
np.random.seed(42)
n_abs = len(presence_vals)
abs_rows = np.random.randint(0, raster_shape[0], n_abs * 3)
abs_cols = np.random.randint(0, raster_shape[1], n_abs * 3)
absence_vals = []
for r, c in zip(abs_rows, abs_cols):
    val = raster_data[r, c]
    if not np.isnan(val):
        absence_vals.append(float(val))
    if len(absence_vals) >= n_abs:
        break
 
y_true = np.array([1] * len(presence_vals) + [0] * len(absence_vals))
y_scores = np.array(presence_vals + absence_vals)
 
plot_roc = os.path.join(output_dir, "roc_curve.png")
if len(np.unique(y_true)) == 2:
    fpr, tpr, _ = roc_curve(y_true, y_scores)
    auc          = roc_auc_score(y_true, y_scores)
    print(f"AUC = {auc:.4f}", flush=True)
    fig, ax = plt.subplots(figsize=(7, 6))
    ax.plot(fpr, tpr, color="#D85A30", linewidth=2, label=f"ARIES model (AUC={auc:.3f})")
    ax.plot([0, 1], [0, 1], "k--", linewidth=1, label="Random (AUC=0.5)")
    ax.fill_between(fpr, tpr, alpha=0.1, color="#D85A30")
    ax.set_xlabel("False Positive Rate"); ax.set_ylabel("True Positive Rate")
    ax.set_title("ROC curve — ARIES as predictor of GloBI pollinator incidences")
    ax.legend()
    plt.tight_layout()
    plt.savefig(plot_roc, dpi=150, bbox_inches="tight"); plt.close()
else:
    print("Insufficient class variation.", flush=True)
    plot_roc = None

if 'biab_output' in globals():
    biab_output("results_csv", csv_path)
    biab_output("gap_raster", gap_raster_path)
    biab_output("plot_correlation", plot_corr)
    biab_output("plot_sampling_bias", plot_bias)
    biab_output("plot_gap_analysis", plot_gap)
    biab_output("plot_taxonomic", plot_tax)
    if plot_roc:
        biab_output("plot_roc", plot_roc)

print("Done.", flush=True)