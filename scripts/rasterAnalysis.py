import json
import os
import sys
import warnings

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import seaborn as sns
import rasterio
from rasterio.enums import Resampling
from scipy import stats
from sklearn.metrics import (
    confusion_matrix, cohen_kappa_score,
    roc_curve, roc_auc_score
)

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

heatmap_path = inputs.get("heatmap_raster")
aries_path = inputs.get("pollinator_raster")
high_aries_threshold = float(inputs.get("high_aries_threshold", 0.6))
high_heat_threshold = float(inputs.get("high_heat_threshold", 0.6))

if not heatmap_path or not os.path.exists(heatmap_path):
    safe_error(f"heatmap_raster not found: {heatmap_path}")
if not aries_path or not os.path.exists(aries_path):
    safe_error(f"pollinator_raster not found: {aries_path}")

#loading rasters
print("Loading rasters.", flush=True)

with rasterio.open(aries_path) as src:
    aries_data = src.read(1).astype(float)
    aries_nodata = src.nodata
    aries_profile = src.profile.copy()
    aries_bounds = src.bounds
    aries_shape = aries_data.shape
    aries_crs = src.crs

if aries_nodata is not None:
    aries_data[aries_data == aries_nodata] = np.nan

valid_aries_mask = ~np.isnan(aries_data)
a_min = float(np.nanmin(aries_data)) if valid_aries_mask.any() else 0.0
a_max = float(np.nanmax(aries_data)) if valid_aries_mask.any() else 1.0

print(f"Original ARIES range: [{a_min:.4f}, {a_max:.4f}]", flush=True)

#Normalize ARIES to [0, 1]
if a_max > a_min:
    aries_data = (aries_data - a_min) / (a_max - a_min)
elif valid_aries_mask.any():
    aries_data[valid_aries_mask] = 0.0

with rasterio.open(heatmap_path) as src:
    heat_data = src.read(
        out_shape=(1, aries_shape[0], aries_shape[1]),
        resampling=Resampling.bilinear
    )[0].astype(float)
    heat_nodata = src.nodata

if heat_nodata is not None:
    heat_data[heat_data == heat_nodata] = np.nan

print(f"ARIES shape: {aries_shape}", flush=True)
print(f"Heatmap shape: {heat_data.shape}", flush=True)

#Normalize heatmap to [0, 1] if not already
heat_min = np.nanmin(heat_data)
heat_max = np.nanmax(heat_data)
if heat_max > heat_min:
    heat_norm = (heat_data - heat_min) / (heat_max - heat_min)
else:
    heat_norm = heat_data.copy()

valid = ~np.isnan(aries_data) & ~np.isnan(heat_norm)
print(f"Valid cells for comparison: {valid.sum():,}", flush=True)

if valid.sum() == 0:
    safe_error("No overlapping valid cells. Check extents and projections.")

flat_aries = aries_data[valid]
flat_heat  = heat_norm[valid]
ext = [aries_bounds.left, aries_bounds.right, aries_bounds.bottom, aries_bounds.top]


# Correlation analysis using Spearman and Pearson coefficients
print("Running correlation analysis.", flush=True)

spearman_r, spearman_p = stats.spearmanr(flat_aries, flat_heat)
pearson_r,  pearson_p = stats.pearsonr(flat_aries,  flat_heat)
print(f"Spearman r={spearman_r:.4f}  p={spearman_p:.4e}", flush=True)
print(f"Pearson  r={pearson_r:.4f}  p={pearson_p:.4e}", flush=True)

fig, axes = plt.subplots(1, 2, figsize=(14, 5))

axes[0].scatter(flat_aries, flat_heat, alpha=0.15, s=4, color="#1D9E75")
m, b = np.polyfit(flat_aries, flat_heat, 1)
xl = np.linspace(flat_aries.min(), flat_aries.max(), 100)
axes[0].plot(xl, m * xl + b, color="#0F6E56", linewidth=2)
axes[0].set_xlabel("ARIES pollinator occurrence value (Normalized)")
axes[0].set_ylabel("Heatmap observation density (normalised)")
axes[0].set_title(
    f"ARIES vs. Heatmap\nSpearman r={spearman_r:.3f}, p={spearman_p:.3e}"
)

h = axes[1].hist2d(flat_aries, flat_heat, bins=50, cmap="YlOrRd")
plt.colorbar(h[3], ax=axes[1], label="Cell count")
axes[1].set_xlabel("ARIES value (Normalized)")
axes[1].set_ylabel("Heatmap value (normalised)")
axes[1].set_title("2D density: ARIES vs. Heatmap")

plt.tight_layout()
plot_corr = os.path.join(output_dir, "correlation_analysis.png")
plt.savefig(plot_corr, dpi=150, bbox_inches="tight")
plt.close()

#Residual map: red where ARIES overpredicts, blue where it underpredicts
print("Computing residual map.", flush=True)

residual = np.full_like(aries_data, np.nan)
residual[valid] = flat_aries - flat_heat   # positive = ARIES overpredicts,negative = ARIES underpredicts

residual_path = os.path.join(output_dir, "residual.tif")
profile = aries_profile.copy()
profile.update(dtype=rasterio.float32, nodata=-9999.0)
with rasterio.open(residual_path, "w", **profile) as dst:
    out = residual.astype(np.float32)
    out[np.isnan(residual)] = -9999.0
    dst.write(out, 1)

fig, ax = plt.subplots(figsize=(9, 6))
vabs = np.nanpercentile(np.abs(residual), 98)
im = ax.imshow(residual, cmap="RdBu_r", origin="upper", extent=ext,
               vmin=-vabs, vmax=vabs)
plt.colorbar(im, ax=ax, label="ARIES − Heatmap (normalised)")
ax.set_title("Residual map\n(+) ARIES overpredicts  |  (−) ARIES underpredicts")
ax.set_xlabel("Longitude")
ax.set_ylabel("Latitude")
plt.tight_layout()
plot_residual = os.path.join(output_dir, "residual_map.png")
plt.savefig(plot_residual, dpi=150, bbox_inches="tight")
plt.close()

#Gap analysis: high-ARIES cells with low heatmap density (undersampling)
print("Running gap analysis.", flush=True)

high_aries = aries_data > high_aries_threshold
low_heat = heat_norm  < (1 - high_heat_threshold)   # invert: low obs density
gap_mask = high_aries & low_heat & ~np.isnan(aries_data) & ~np.isnan(heat_norm)

n_high= int(high_aries.sum())
n_gap = int(gap_mask.sum())
gap_pct = 100.0 * n_gap / n_high if n_high > 0 else 0.0
print(f"High-ARIES cells: {n_high:,}  Gap cells: {n_gap:,} ({gap_pct:.1f}%)",
      flush=True)

gap_raster = np.zeros_like(aries_data, dtype=np.uint8)
gap_raster[gap_mask] = 1

gap_raster_path = os.path.join(output_dir, "gap_analysis.tif")
gap_profile = aries_profile.copy()
gap_profile.update(dtype=rasterio.uint8, nodata=255)
with rasterio.open(gap_raster_path, "w", **gap_profile) as dst:
    out = gap_raster.copy()
    out[np.isnan(aries_data)] = 255
    dst.write(out, 1)

cmap_gap = mcolors.ListedColormap(["#f0f0f0", "#E24B4A"])
fig, axes = plt.subplots(1, 3, figsize=(18, 5))

im0 = axes[0].imshow(aries_data, cmap="YlOrRd", origin="upper", extent=ext)
plt.colorbar(im0, ax=axes[0], label="ARIES value (Normalized)")
axes[0].set_title("ARIES pollinator occurrence")

im1 = axes[1].imshow(heat_norm, cmap="Blues", origin="upper", extent=ext)
plt.colorbar(im1, ax=axes[1], label="Heatmap (normalised)")
axes[1].set_title("Observation heatmap")

im2 = axes[2].imshow(gap_raster, cmap=cmap_gap, origin="upper", extent=ext,
                     vmin=0, vmax=1)
cbar2 = plt.colorbar(im2, ax=axes[2], ticks=[0.25, 0.75])
cbar2.ax.set_yticklabels(["observed / low ARIES", "gap"])
axes[2].set_title(
    f"Gap analysis\n{gap_pct:.1f}% of high-ARIES cells undersampled"
)

for ax in axes:
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")

plt.tight_layout()
plot_gap = os.path.join(output_dir, "gap_analysis.png")
plt.savefig(plot_gap, dpi=150, bbox_inches="tight")
plt.close()

# Confusion matrix: do they agree?
print("Running binary agreement analysis.", flush=True)

aries_bin = (flat_aries >= high_aries_threshold).astype(int)
heat_bin = (flat_heat  >= high_heat_threshold).astype(int)

cm = confusion_matrix(heat_bin, aries_bin)
kappa = cohen_kappa_score(heat_bin, aries_bin)

tn, fp, fn, tp = cm.ravel()
sensitivity = tp / (tp + fn) if (tp + fn) > 0 else 0.0
specificity = tn / (tn + fp) if (tn + fp) > 0 else 0.0
print(f"Kappa={kappa:.4f}  Sensitivity={sensitivity:.4f}  "
      f"Specificity={specificity:.4f}", flush=True)

fig, ax = plt.subplots(figsize=(6, 5))
sns.heatmap(
    cm, annot=True, fmt="d", cmap="Blues", ax=ax,
    xticklabels=["ARIES low", "ARIES high"],
    yticklabels=["Heatmap low", "Heatmap high"]
)
ax.set_title(
    f"Confusion matrix (binary agreement)\n"
    f"Cohen κ={kappa:.3f}  Sensitivity={sensitivity:.3f}  "
    f"Specificity={specificity:.3f}"
)
ax.set_ylabel("Heatmap (observed)")
ax.set_xlabel("ARIES (predicted)")
plt.tight_layout()
plot_cm = os.path.join(output_dir, "confusion_matrix.png")
plt.savefig(plot_cm, dpi=150, bbox_inches="tight")
plt.close()

#Receiver operating curve
print("Running ROC analysis.", flush=True)

fpr, tpr, _ = roc_curve(heat_bin, flat_aries)
auc = roc_auc_score(heat_bin, flat_aries)
print(f"AUC={auc:.4f}", flush=True)

fig, ax = plt.subplots(figsize=(7, 6))
ax.plot(fpr, tpr, color="#D85A30", linewidth=2,
        label=f"ARIES model (AUC={auc:.3f})")
ax.plot([0, 1], [0, 1], "k--", linewidth=1, label="Random (AUC=0.5)")
ax.fill_between(fpr, tpr, alpha=0.1, color="#D85A30")
ax.set_xlabel("False Positive Rate")
ax.set_ylabel("True Positive Rate")
ax.set_title("ROC curve\nARIES as predictor of heatmap high-density cells")
ax.legend()
plt.tight_layout()
plot_roc = os.path.join(output_dir, "roc_curve.png")
plt.savefig(plot_roc, dpi=150, bbox_inches="tight")
plt.close()

#Hotspot overlap
print("Running hotspot overlap analysis.", flush=True)

n_heat_hotspot = int(heat_bin.sum())
n_aries_hotspot = int(aries_bin.sum())
n_overlap = int((heat_bin & aries_bin).sum())
pct_heat_covered = 100.0 * n_overlap / n_heat_hotspot  if n_heat_hotspot  > 0 else 0.0
pct_aries_covered = 100.0 * n_overlap / n_aries_hotspot if n_aries_hotspot > 0 else 0.0

print(f"Heatmap hotspots: {n_heat_hotspot:,}")
print(f"ARIES hotspots: {n_aries_hotspot:,}")
print(f"Overlap: {n_overlap:,} "
      f"({pct_heat_covered:.1f}% of heatmap hotspots, "
      f"{pct_aries_covered:.1f}% of ARIES hotspots)", flush=True)

overlap_grid = np.zeros(aries_shape, dtype=np.uint8)
overlap_grid[valid] = (
    (aries_data[valid] >= high_aries_threshold).astype(np.uint8) * 2 +
    (heat_norm[valid]>= high_heat_threshold).astype(np.uint8)
)
# 0 = neither, 1 = heatmap only, 2 = ARIES only, 3 = both

cmap_overlap = mcolors.ListedColormap(
    ["#e0e0e0", "#4292C6", "#FB6A4A", "#238B45"]
)
bounds_c = [-0.5, 0.5, 1.5, 2.5, 3.5]
norm_c   = mcolors.BoundaryNorm(bounds_c, cmap_overlap.N)

fig, ax = plt.subplots(figsize=(9, 7))
im = ax.imshow(overlap_grid, cmap=cmap_overlap, norm=norm_c,
               origin="upper", extent=ext)
cbar = plt.colorbar(im, ax=ax, ticks=[0, 1, 2, 3])
cbar.ax.set_yticklabels(["Neither", "Heatmap only", "ARIES only", "Both"])
ax.set_title(
    f"Hotspot overlap\n"
    f"{pct_heat_covered:.1f}% of heatmap hotspots captured by ARIES  |  "
    f"κ={kappa:.3f}"
)
ax.set_xlabel("Longitude")
ax.set_ylabel("Latitude")
plt.tight_layout()
plot_hotspot = os.path.join(output_dir, "hotspot_overlap.png")
plt.savefig(plot_hotspot, dpi=150, bbox_inches="tight")
plt.close()


if 'biab_output' in globals():
    biab_output("residual_raster",    residual_path)
    biab_output("gap_raster",         gap_raster_path)
    biab_output("plot_correlation",   plot_corr)
    biab_output("plot_residual",      plot_residual)
    biab_output("plot_gap_analysis",  plot_gap)
    biab_output("plot_confusion",     plot_cm)
    biab_output("plot_roc",           plot_roc)
    biab_output("plot_hotspot",       plot_hotspot)

print("Done.", flush=True)