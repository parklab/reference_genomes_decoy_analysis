library(ggplot2)
library(patchwork)

# Derive repo root from this script's location (3 levels up) for default paths.
script_dir  <- dirname(normalizePath(sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))][[1]])))
repo_root   <- normalizePath(file.path(script_dir, "../../.."))

args        <- commandArgs(trailingOnly = TRUE)
data_dir    <- if (length(args) >= 1) args[1] else file.path(repo_root, "results", "intermediate", "simulated_reads_alignment_location")
figures_dir <- if (length(args) >= 2) args[2] else file.path(repo_root, "results", "figures", "fig2b")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

data_hs37d5 <- read.csv(file.path(data_dir, "panel_hs37d5.csv"), header=FALSE, col.names=c("sample", "category", "percent"))
data_hs38d1 <- read.csv(file.path(data_dir, "panel_hs38d1.csv"), header=FALSE, col.names=c("sample", "category", "percent"))

category_order <- c("Main chromosomes", "Unplaced sequence", "Decoy sequence", "Unmapped")
category_colors <- c("Main chromosomes" = "#425ab3",
                     "Unplaced sequence" = "#8999d2",
                     "Decoy sequence"    = "#ff9e1c",
                     "Unmapped"          = "#d9d9d9")

sample_order <- c("GRCh37", "GATK b37", "GRCh37d5", "GRCh38", "GATK hg38", "GRCh38d1", "T2T")

font_size <- 12

create_plot <- function(data, plot_title) {
  data$category <- factor(data$category, levels = category_order)
  data$sample   <- factor(data$sample,   levels = sample_order)

  ggplot(data, aes(x=sample, y=percent, fill=category)) +
    geom_bar(stat="identity", position="stack") +
    scale_fill_manual(values = category_colors) +
    geom_text(data = subset(data, percent > 0.1),
              aes(label = sprintf("%0.1f%%", percent)),
              position = position_stack(vjust = 0.5), size = 3.5) +
    labs(title = plot_title, x = "Reference", y = "Percent") +
    theme_classic() +
    theme(
      legend.position   = "none",
      axis.text.x       = element_text(size = font_size, angle = 90, hjust = 1, vjust = 0.5),
      axis.text.y       = element_text(size = font_size),
      axis.title        = element_text(size = font_size + 1),
      plot.title        = element_text(size = font_size + 2),
      plot.background   = element_rect(fill = "white", color = NA),
      panel.background  = element_rect(fill = "white", color = NA),
      plot.margin       = unit(c(.1,.1,.1,.1), "cm"),
      axis.line         = element_line(color = "black")
    )
}

plot_hs37d5 <- create_plot(data_hs37d5, "hs37d5")
plot_hs38d1 <- create_plot(data_hs38d1, "hs38d1")

combined <- plot_hs37d5 + plot_hs38d1

ggsave(file.path(figures_dir, "fig2b.pdf"), combined, width = 20, height = 10, dpi = 300)
ggsave(file.path(figures_dir, "fig2b.png"), combined, width = 20, height = 10, dpi = 300)
