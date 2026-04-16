library(ggplot2)
library(dplyr)
library(patchwork)

# Derive repo root from this script's location (3 levels up) for default paths.
script_dir  <- dirname(normalizePath(sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))][[1]])))
repo_root   <- normalizePath(file.path(script_dir, "../../.."))

args        <- commandArgs(trailingOnly = TRUE)
data_dir    <- if (length(args) >= 1) args[1] else file.path(repo_root, "results", "intermediate", "simulated_reads_alignment_quality")
figures_dir <- if (length(args) >= 2) args[2] else file.path(repo_root, "results", "figures", "fig2c")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

# Maps filename prefix to display label (and defines plot order).
SAMPLE_MAP <- c(
  "grch37"                   = "GRCh37",
  "b37"                      = "GATK b37",
  "grch37d5"                 = "GRCh37d5",
  "grch38_no_alt"            = "GRCh38",
  "hg38_gatk"                = "GATK hg38",
  "grch38_no_alt_plus_decoy" = "GRCh38d1",
  "t2t"                      = "T2T"
)

SAMPLE_ORDER <- c("GRCh37", "GRCh38", "GATK b37", "GATK hg38", "GRCh37d5", "GRCh38d1", "T2T")

SAMPLE_COLORS <- c(
  "GRCh37"    = "#83d7ec",
  "GRCh38"    = "#f2cf92",
  "GATK b37"  = "#1d92af",
  "GATK hg38" = "#e8ac41",
  "GRCh37d5"  = "#0f4c5c",
  "GRCh38d1"  = "#b67b16",
  "T2T"       = "#65010e"
)

SAMPLE_PCHS <- c(
  "GRCh37"    = 0,
  "GRCh38"    = 5,
  "GATK b37"  = 3,
  "GATK hg38" = 2,
  "GRCh37d5"  = 4,
  "GRCh38d1"  = 6,
  "T2T"       = 1
)

load_panel <- function(bam_suffix) {
  file_list <- file.path(data_dir, paste0(names(SAMPLE_MAP), ".", bam_suffix, ".txt"))
  present   <- file_list[file.exists(file_list)]
  missing   <- file_list[!file.exists(file_list)]
  if (length(missing) > 0) {
    warning("Missing data files: ", paste(missing, collapse = ", "))
  }

  lapply(present, function(f) {
    prefix <- sub("\\..*", "", basename(f))
    read.table(f, header = FALSE, sep = ",", col.names = c("MAPQ", "Coverage")) %>%
      mutate(sample = SAMPLE_MAP[prefix])
  }) %>%
    bind_rows() %>%
    mutate(sample = factor(sample, levels = SAMPLE_ORDER))
}

create_plot <- function(data, plot_title) {
  ggplot(data, aes(x = MAPQ, y = Coverage, color = sample, shape = sample)) +
    geom_line(linetype = "solid", show.legend = FALSE) +
    geom_point(size = 2.5) +
    scale_color_manual(values = SAMPLE_COLORS) +
    scale_shape_manual(values = SAMPLE_PCHS) +
    labs(x = "MAPQ", y = "Coverage", title = plot_title) +
    theme_bw() +
    theme(
      legend.title    = element_blank(),
      legend.position = "bottom",
      legend.box      = "horizontal",
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank()
    )
}

data_hs37d5 <- load_panel("hs37d5")
data_hs38d1 <- load_panel("hs38d1")

plot_hs37d5 <- create_plot(data_hs37d5, "hs37d5")
plot_hs38d1 <- create_plot(data_hs38d1, "hs38d1")

combined <- plot_hs37d5 + plot_hs38d1 + plot_layout(guides = "collect") &
  theme(legend.position = "bottom")

ggsave(file.path(figures_dir, "fig2c.pdf"), combined, width = 12, height = 6, dpi = 300)
ggsave(file.path(figures_dir, "fig2c.png"), combined, width = 12, height = 6, dpi = 300)
