#' @title Analysis of TOP Framework UX Survey Results
#'
#' @description
#' This script processes and analyzes data collected from an online survey
#' evaluating user experience (UX) with the TOP Framework. It includes steps
#' for data preprocessing, calculation of summary statistics for UX-related
#' scales, and generation of tables and visualizations to facilitate
#' interpretation of the survey findings. The script is intended for research
#' and reporting purposes, using survey data provided in CSV format.
#'
#' @details
#' The analysis supports understanding of user perceptions and experiences
#' with the TOP Framework, providing insights for further development and
#' improvement.

library(tidyverse)
library(gtsummary)
library(gt)

theme_gtsummary_mean_sd()
style_number_2digits <- purrr::partial(style_number, digits = 2)

data <- read.csv("data/NWGTOP_DATA_2025-03-28_1019.csv")

result <- data %>%
  select(record_id, matches("q_\\d+")) %>%
  filter(if_any(q_1:q_26, ~ !is.na(.x))) %>%
  mutate(
    # scales are ordered randomely and must be standardized to the interval [-3; 3]
    across(c(q_1:q_2, q_6:q_8, q_11, q_13:q_16, q_20, q_22, q_26), ~ .x - 4),
    across(c(q_3:q_5, q_9:q_10, q_12, q_17:q_19, q_21, q_23:q_25), ~ 4 - .x),
    # calculate mean values for each scale
    attractiveness = mean(c(q_1, q_12, q_14, q_16, q_24, q_25), na.rm = TRUE),
    perspicuity = mean(c(q_2, q_4, q_13, q_21), na.rm = TRUE),
    efficiency = mean(c(q_9, q_20, q_22, q_23), na.rm = TRUE),
    dependability = mean(c(q_8, q_11, q_17, q_19), na.rm = TRUE),
    stimulation = mean(c(q_5, q_6, q_7, q_18), na.rm = TRUE),
    novelity = mean(c(q_3, q_10, q_15, q_26), na.rm = TRUE),
    attractiveness_quality = attractiveness,
    pragmatic_quality = mean(c(perspicuity, efficiency, dependability)),
    hedonic_quality = mean(c(stimulation, novelity)),
    .by = record_id
  ) %>%
  select(-starts_with("q_"))

result %>%
  tbl_summary(
    include = -record_id,
    type = everything() ~ "continuous2",
    missing = "no",
    statistic = all_continuous() ~ c(
      "{mean} ({sd})",
      "{min} - {max}",
      "{median} ({p25}, {p75})"
    ),
  ) %>%
  add_ci(style_fun = list(everything() ~ style_number_2digits)) %>%
  as_gt() %>%
  tab_row_group("grouped scales", rows = 25:36) %>%
  tab_row_group("scales", rows = 1:24)

result %>%
  pivot_longer(attractiveness:novelity) %>%
  group_by(name) %>%
  rstatix::t_test(value ~ 1, mu = 0.8, alternative = "greater", detailed = TRUE) %>%
  rstatix::add_significance() %>%
  select(name, n, estimate, alternative, conf.low, conf.high, p, p.signif) %>%
  gt() %>%
  fmt_number(-n, decimals = 3)

result %>%
  summarise(
    across(
      c(attractiveness, perspicuity, efficiency, dependability, stimulation, novelity),
      .fns = list(mean = mean, margin = ~ qt(0.975, df = n() - 1) * sd(.) / sqrt(n()))
    )
  ) %>%
  tidyr::pivot_longer(
    everything(),
    names_sep = "_",
    names_to = c("scale", "property"),
  ) %>%
  tidyr::pivot_wider(
    names_from = property,
    values_from = value
  ) %>%
  mutate(scale = factor(
    scale,
    c("attractiveness", "perspicuity", "efficiency", "dependability", "stimulation", "novelity")
  )) %>%
  ggplot(aes(scale, mean)) +
  annotate(
    geom = "rect",
    xmin = -Inf,
    xmax = Inf,
    ymin = c(-Inf, -0.8, 0.8),
    ymax = c(-0.8, 0.8, Inf),
    fill = c("red", "yellow", "green"),
    alpha = 0.2
  ) +
  geom_hline(yintercept = c(-0.8, 0, 0.8), linetype = c("dashed", "solid", "dashed")) +
  geom_bar(stat = "identity", width = 0.8, fill = "gray50") +
  geom_errorbar(
    aes(ymin = mean - margin, ymax = mean + margin),
    width = 0.3,
    linewidth = 1
  ) +
  theme_minimal() +
  theme(
    axis.text = element_text(size = 15),
    axis.title = element_text(size = 20, colour = "gray30"),
  ) +
  xlab(NULL) +
  coord_cartesian(ylim = c(-1, 2.5))

ggsave("data/scale_means.png", width = 10, height = 6)
