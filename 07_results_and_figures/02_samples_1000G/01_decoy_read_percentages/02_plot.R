library(ggplot2)
library(dplyr)
library(tidyr)

# Paths relative to this script's location
script_dir  <- dirname(normalizePath(sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))][[1]]), mustWork = FALSE))
repo_root   <- normalizePath(file.path(script_dir, "../../.."), mustWork = FALSE)
data_file   <- file.path(repo_root, "results/intermediate/decoy_reads_samples/decoy_read_stats/percentage_decoy_reads/decoy_read_percentages.csv")
out_dir     <- file.path(repo_root, "results/figures/decoy_read_percentages")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Read unified CSV and reshape to long format with 4 groups:
#   hs37d5 × all reads, hs37d5 × MAPQ≥20, hs38d1 × all reads, hs38d1 × MAPQ≥20
data <- read.csv(data_file) %>%
  select(sample, decoy, pct_mapq0, pct_mapq20) %>%
  pivot_longer(cols = c(pct_mapq0, pct_mapq20),
               names_to  = "mapq",
               values_to = "proportion") %>%
  mutate(
    proportion = proportion / 100,
    group = factor(
      paste(decoy, mapq, sep = "_"),
      levels = c("hs37d5_pct_mapq0", "hs37d5_pct_mapq20", "hs38d1_pct_mapq0", "hs38d1_pct_mapq20")
    )
  )

colors       <- c("#0f4c5c", "#0f4c5c", "#b67b16", "#b67b16")
point_colors <- c("#072e38", "#072e38", "#7a520f", "#7a520f")
font_size    <- 7

ggplot(data, aes(x = group, y = proportion, fill = group)) +
  geom_boxplot(outlier.color = NA, alpha = 0.8) +
  scale_fill_manual(values = colors) +
  geom_jitter(aes(color = group), size = 1, width = 0.3, alpha = 0.95) +
  scale_color_manual(values = point_colors) +
  scale_x_discrete(labels = c(
    "hs37d5 all reads", "hs37d5 MAPQ\u226520",
    "hs38d1 all reads", "hs38d1 MAPQ\u226520"
  )) +
  labs(
    title = "Proportion of reads mapping to decoy",
    x     = "Reference",
    y     = "Proportion"
  ) +
  theme(
    legend.position  = "none",
    panel.border     = element_blank(),
    panel.background = element_rect(fill = "white"),
    axis.line        = element_line(color = "black", linewidth = 0.2),
    axis.text.x      = element_text(size = font_size - 2, angle = 20, hjust = 1),
    axis.text.y      = element_text(size = font_size - 2),
    axis.title       = element_text(size = font_size - 1),
    plot.title       = element_text(size = font_size)
  )

ggsave(file.path(out_dir, "decoy_read_percentages.pdf"), width = 4, height = 4, dpi = 300)
ggsave(file.path(out_dir, "decoy_read_percentages.png"), width = 4, height = 4, dpi = 300)
