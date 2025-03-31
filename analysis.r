library(dplyr)
library(gtsummary)
library(gt)
library(ggplot2)

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
    type = everything() ~ "continuous",
    missing = "no"
  ) %>%
  add_ci(style_fun = list(everything() ~ style_number_2digits)) %>%
  as_gt() %>%
  tab_row_group("grouped scales", rows = 7:9) %>%
  tab_row_group("scales", rows = 1:6)

result %>%
  summarise(across(c(attractiveness, perspicuity, efficiency, dependability, stimulation, novelity), mean)) %>%
  tidyr::pivot_longer(
    c(attractiveness, perspicuity, efficiency, dependability, stimulation, novelity),
    names_to = "scale",
  ) %>%
  ggplot(aes(scale, value)) +
  annotate(
    geom = "rect",
    xmin = -Inf,
    xmax = Inf,
    ymin = c(-2, -0.8, 0.8),
    ymax = c(-0.8, 0.8, 2),
    fill = c("red", "yellow", "green"),
    alpha = 0.3
  ) +
  geom_hline(yintercept = 0) +
  geom_bar(stat = "identity") +
  theme_minimal() +
  coord_cartesian(ylim = c(-2, 2))

ggsave("data/scale_means.png", width = 10, height = 5)
