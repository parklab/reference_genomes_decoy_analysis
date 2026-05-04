library(ggplot2)
library(dplyr)
library(patchwork)

script_dir  <- dirname(normalizePath(sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))][[1]]), mustWork = FALSE))
repo_root   <- normalizePath(file.path(script_dir, "../../.."), mustWork = FALSE)

args        <- commandArgs(trailingOnly = TRUE)
data_file   <- if (length(args) >= 1) args[1] else file.path(repo_root, "results/intermediate/decoy_reads_samples/decoy_read_stats/supplementary_alignment_rate/supplementary_alignment_rate.csv")
figures_dir <- if (length(args) >= 2) args[2] else file.path(repo_root, "results/figures/supplementary_alignment_rate")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

REF_MAP <- c(
  "grch37"                   = "GRCh37",
  "b37"                      = "GATK b37",
  "grch37d5"                 = "GRCh37d5",
  "grch38_no_alt"            = "GRCh38",
  "hg38_gatk"                = "GATK hg38",
  "grch38_no_alt_plus_decoy" = "GRCh38d1",
  "t2t"                      = "T2T"
)

REF_ORDER <- c("GRCh37", "GATK b37", "GRCh37d5", "GRCh38", "GATK hg38", "GRCh38d1", "T2T")

REF_COLORS <- c(
  "GRCh37"    = "#83d7ec",
  "GATK b37"  = "#1d92af",
  "GRCh37d5"  = "#0f4c5c",
  "GRCh38"    = "#f2cf92",
  "GATK hg38" = "#e8ac41",
  "GRCh38d1"  = "#b67b16",
  "T2T"       = "#65010e"
)

# Darker shades for jitter points
POINT_COLORS <- c(
  "GRCh37"    = "#4baec9",
  "GATK b37"  = "#0d6b82",
  "GRCh37d5"  = "#072e38",
  "GRCh38"    = "#d4a84a",
  "GATK hg38" = "#b07d20",
  "GRCh38d1"  = "#7a520f",
  "T2T"       = "#3d0007"
)

font_size <- 7

data <- read.csv(data_file) %>%
  mutate(
    ref_label = factor(REF_MAP[ref], levels = REF_ORDER),
    rate_supplementary = as.numeric(pct_supplementary) / 100
  ) %>%
  filter(!is.na(ref_label), !is.na(rate_supplementary))

create_panel <- function(df, panel_title) {
  ggplot(df, aes(x = ref_label, y = rate_supplementary, fill = ref_label)) +
    geom_boxplot(outlier.color = NA, alpha = 0.8) +
    scale_fill_manual(values = REF_COLORS) +
    geom_jitter(aes(color = ref_label), size = 1, width = 0.3, alpha = 0.95) +
    scale_color_manual(values = POINT_COLORS) +
    labs(title = panel_title, x = "Reference", y = "Supplementary alignment rate") +
    theme(
      legend.position  = "none",
      panel.border     = element_blank(),
      panel.background = element_rect(fill = "white"),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line        = element_line(color = "black", linewidth = 0.5),
      axis.text.x      = element_text(size = font_size - 2, angle = 90, hjust = 1, vjust = 0.5),
      axis.text.y      = element_text(size = font_size - 2),
      axis.title       = element_text(size = font_size - 1),
      plot.title       = element_text(size = font_size)
    )
}

plot_hs37d5 <- create_panel(filter(data, decoy == "hs37d5"), "hs37d5 decoy reads")
plot_hs38d1 <- create_panel(filter(data, decoy == "hs38d1"), "hs38d1 decoy reads")

combined <- plot_hs37d5 + plot_hs38d1

ggsave(file.path(figures_dir, "supplementary_alignment_rate.pdf"), combined, width = 8, height = 4, dpi = 300)
ggsave(file.path(figures_dir, "supplementary_alignment_rate.png"), combined, width = 8, height = 4, dpi = 300)
