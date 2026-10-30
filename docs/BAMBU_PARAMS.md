# Bambu Studio 可调参数全清单

> 自动从 `libslic3r/PrintConfig.cpp` 的 `PrintConfigDef` 提取，不是凭记忆整理的。

> 共 **744** 项：有显示名（UI 可调）**544** 项，无显示名（内核内部）**200** 项。

> `等级` = 桌面版「简单/高级/开发」显示档；`阶段` = 本 App 接入批次；`状态` ✅已接入 ⬜未接入。


## 一、总览

| 分类 | 参数数 | 可调 | 简单 | 高级 | 已接入 |
|---|---:|---:|---:|---:|---:|
| Others / Internal | 341 | 195 | 186 | 114 | 6 |
| Quality | 77 | 76 | 10 | 58 | 10 |
| Filament | 73 | 56 | 19 | 27 | 5 |
| Support | 72 | 52 | 14 | 47 | 19 |
| Strength | 54 | 54 | 17 | 36 | 3 |
| Speed | 43 | 37 | 9 | 34 | 1 |
| Cooling | 21 | 19 | 11 | 6 | 0 |
| Machine limits | 15 | 7 | 2 | 8 | 0 |
| Others | 13 | 13 | 10 | 3 | 0 |
| Retraction | 13 | 13 | 2 | 6 | 0 |
| Advanced | 8 | 8 | 0 | 8 | 0 |
| Extruders | 4 | 4 | 0 | 3 | 3 |
| Adhesion | 4 | 4 | 2 | 0 | 0 |
| Flush options | 3 | 3 | 3 | 0 | 0 |
| G-code | 2 | 2 | 0 | 1 | 1 |
| Other | 1 | 1 | 0 | 1 | 0 |
| **合计** | **744** | **544** | **285** | **352** | **48** |

## 二、接入批次计划

| 批次 | 主题 | 参数数 | 状态 |
|---|---|---:|---|
| P1 | 壳层/顶底面/接缝/补偿 | 18 | 本轮接入 |
| P2 | 速度 | 11 | 待接入 |
| P3 | 回抽与 Z hop | 8 | 待接入 |
| P4 | 冷却风扇 | 9 | 待接入 |

## 三、逐批明细


### P1

| 键名 | 显示名 | 类型 | 默认值 | 单位 | 等级 |
|---|---|---|---|---|---|
| `bottom_shell_layers` | Bottom shell layers | Int | 3 |  | 简单 |
| `bottom_shell_thickness` | Bottom shell thickness | Float | 0. | mm | 简单 |
| `bottom_surface_pattern` | Bottom surface pattern | Enum | ipRectilinear |  | 简单 |
| `elefant_foot_compensation` | Elephant foot compensation | Float | 0. | mm | 高级 |
| `ensure_vertical_shell_thickness` | Ensure vertical shell thicknes | Enum | EnsureVerticalTh |  | 高级 |
| `internal_solid_infill_pattern` | Internal solid infill pattern | Enum | ipRectilinear |  | 简单 |
| `ironing_type` | Ironing Type | Enum | IroningType::NoI |  | 高级 |
| `minimum_sparse_infill_area` | Minimum sparse infill threshol | Float | 15 | mm² | 高级 |
| `only_one_wall_first_layer` | Only one wall on first layer | Bool | false |  | 简单 |
| `seam_position` | Seam position | Enum | spAligned |  | 简单 |
| `sparse_infill_anchor` | Length of sparse infill anchor | FloatOrPercent | 400, true | mm or % | 高级 |
| `sparse_infill_anchor_max` | Maximum length of sparse infil | FloatOrPercent | 20, false |  | 简单 |
| `top_shell_layers` | Top shell layers | Int | 4 |  | 简单 |
| `top_shell_thickness` | Top shell thickness | Float | 0.6 | mm | 简单 |
| `top_surface_pattern` | Top surface pattern | Enum | ipRectilinear |  | 简单 |
| `wall_sequence` | Order of walls | Enum | WallSequence::In |  | 高级 |
| `xy_contour_compensation` | X-Y contour compensation | Float | 0 | mm | 高级 |
| `xy_hole_compensation` | X-Y hole compensation | Float | 0 | mm | 高级 |

### P2

| 键名 | 显示名 | 类型 | 默认值 | 单位 | 等级 |
|---|---|---|---|---|---|
| `bridge_speed` | Bridge | Floats | 25 | mm/s | 高级 |
| `initial_layer_infill_speed` | Initial layer infill | Floats | 60.0 | mm/s | 高级 |
| `initial_layer_speed` | Initial layer | Floats | 30 | mm/s | 高级 |
| `inner_wall_speed` | Inner wall | Floats | 60 | mm/s | 高级 |
| `internal_solid_infill_speed` | Internal solid infill | Floats | 100 | mm/s | 高级 |
| `outer_wall_speed` | Outer wall | Floats | 60 | mm/s | 高级 |
| `sparse_infill_speed` | Sparse infill | Floats | 100 | mm/s | 高级 |
| `support_interface_speed` | Support interface | Floats | 80 | mm/s | 高级 |
| `support_speed` | Support | Floats | 80 | mm/s | 高级 |
| `top_surface_speed` | Top surface | Floats | 100 | mm/s | 高级 |
| `travel_speed` | Travel | Floats | 120 | mm/s | 高级 |

### P3

| 键名 | 显示名 | 类型 | 默认值 | 单位 | 等级 |
|---|---|---|---|---|---|
| `reduce_crossing_wall` | Avoid crossing wall | Bool | false |  | 高级 |
| `retraction_length` | Length | Floats | 0.8 | mm | 简单 |
| `retraction_minimum_travel` | Travel distance threshold | Floats | 2. | mm | 高级 |
| `retraction_speed` | Retraction Speed | Floats | 30. | mm/s | 高级 |
| `wipe` | Wipe while retracting | Bools | false |  | 高级 |
| `wipe_distance` | Wipe Distance | Floats | 2. | mm | 高级 |
| `z_hop` | Z hop when retract | Floats | 0.4 | mm | 简单 |
| `z_hop_types` | Z Hop Type | Enums | ZHopType::zhtSpi |  | 高级 |

### P4

| 键名 | 显示名 | 类型 | 默认值 | 单位 | 等级 |
|---|---|---|---|---|---|
| `close_fan_the_first_x_layers` | For the first | Ints | 1 | layers | 简单 |
| `enable_overhang_bridge_fan` | Force cooling for overhang and | Bools | true |  | 简单 |
| `fan_cooling_layer_time` | Layer time | Ints | 60 | s | 简单 |
| `fan_max_speed` | Fan speed | Ints | 100 |  | 简单 |
| `fan_min_speed` | Fan speed | Ints | 20 |  | 简单 |
| `full_fan_speed_layer` | Full fan speed at layer | Ints | 0 |  | 简单 |
| `overhang_fan_speed` | Fan speed for overhang | Ints | 100 |  | 高级 |
| `slow_down_for_layer_cooling` | Slow printing down for better  | Bools | true |  | 简单 |
| `slow_down_layer_time` | Layer time | Ints | 5 | s | 简单 |

## 四、完整参数表


### Quality（77 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `adaptive_layer_height` | Adaptive layer height | Bool | 0 |  |  | 简单 |  | ⬜ |
| `enable_mixed_color_sublayer` | Mixed color sublayer | Bool | false |  |  | 简单 |  | ⬜ |
| `first_layer_sequence_choice` | First layer filament seq | Enum | flsAuto |  |  | 简单 |  | ⬜ |
| `initial_layer_height` |   | Float | 0.3 | 0~ |   | 简单 |  | ⬜ |
| `initial_layer_print_height` | Initial layer height | Float | 0.2 | 0~ | mm | 简单 |  | ⬜ |
| `layer_height` | Layer height | Float | 0.2 | 0~ | mm | 简单 |  | ✅ |
| `only_one_wall_first_layer` | Only one wall on first l | Bool | false |  |  | 简单 | P1 | ⬜ |
| `other_layers_sequence_choice` | Other layers filament se | Enum | flsAuto |  |  | 简单 |  | ⬜ |
| `seam_position` | Seam position | Enum | spAligned |  |  | 简单 | P1 | ⬜ |
| `top_one_wall_type` | Only one wall on top sur | Enum | TopOneWallType |  |  | 简单 |  | ⬜ |
| `avoid_crossing_wall_includes_support` | Avoid crossing wall - In | Bool | false |  |  | 高级 |  | ⬜ |
| `bridge_flow` | Bridge flow | Float | 1 | 0~2.0 |  | 高级 |  | ⬜ |
| `counterbore_hole_bridging` | Bridge counterbore holes | Enum | chbNone |  |  | 高级 |  | ⬜ |
| `elefant_foot_compensation` | Elephant foot compensati | Float | 0. | 0~ | mm | 高级 | P1 | ⬜ |
| `initial_layer_acceleration` | Initial layer | Floats | 300 | 0~ |  | 高级 |  | ⬜ |
| `initial_layer_infill_line_width` | Initial layer infill | Float | 0 | 0~ | mm | 高级 |  | ⬜ |
| `initial_layer_infill_speed` | Initial layer infill | Floats | 60.0 | 1~ | mm/s | 高级 | P2 | ⬜ |
| `initial_layer_jerk` | First layer | Float | 9 | 0~ | mm/s | 高级 |  | ⬜ |
| `initial_layer_line_width` | Initial layer | Float | 0.4 | 0~ | mm | 高级 |  | ✅ |
| `initial_layer_speed` | Initial layer | Floats | 30 | 0~ | mm/s | 高级 | P2 | ⬜ |
| `initial_layer_travel_acceleration` | Initial layer travel | Floats | 500.0 | 0~ |  | 高级 |  | ⬜ |
| `inner_wall_acceleration` | Inner wall | Floats | 0 | 0~ |  | 高级 |  | ⬜ |
| `inner_wall_jerk` | Inner wall | Float | 9 | 0~ | mm/s | 高级 |  | ⬜ |
| `inner_wall_line_width` | Inner wall | Float | 0.4 | 0~ | mm | 高级 |  | ✅ |
| `internal_solid_infill_line_width` | Internal solid infill | Float | 0.4 | 0~ | mm | 高级 |  | ✅ |
| `ironing_flow` | Ironing flow | Percent | 10 | 0~100 |  | 高级 |  | ⬜ |
| `ironing_inset` | Ironing inset | Float | 0 | 0~100 | mm | 高级 |  | ⬜ |
| `ironing_pattern` | Ironing Pattern | Enum | ipRectilinear |  |  | 高级 |  | ⬜ |
| `ironing_spacing` | Ironing line spacing | Float | 0.1 | 0~1 | mm | 高级 |  | ⬜ |
| `ironing_speed` | Ironing speed | Float | 20 | 0~ | mm/s | 高级 |  | ⬜ |
| `ironing_type` | Ironing Type | Enum | IroningType::N |  |  | 高级 | P1 | ⬜ |
| `is_infill_first` | Print infill first | Bool | false |  |  | 高级 |  | ⬜ |
| `line_width` | Default | Float | 0.4 | 0~10 | mm | 高级 |  | ✅ |
| `max_travel_detour_distance` | Avoid crossing wall - Ma | FloatOrPercent | 0., false | 0~ | mm or % | 高级 |  | ⬜ |
| `min_bead_width` | Minimum wall width | Percent | 85 | 0~ |  | 高级 |  | ⬜ |
| `min_feature_size` | Minimum feature size | Percent | 25 | 0~ |  | 高级 |  | ⬜ |
| `outer_wall_acceleration` | Outer wall | Floats | 500 | 0~ |  | 高级 |  | ⬜ |
| `outer_wall_jerk` | Outer wall | Float | 9 | 0~ | mm/s | 高级 |  | ⬜ |
| `outer_wall_line_width` | Outer wall | Float | 0 | 0~ | mm | 高级 |  | ✅ |
| `override_filament_scarf_seam_setting` | Override filament scarf  | Bool | false |  |  | 高级 |  | ⬜ |
| `reduce_crossing_wall` | Avoid crossing wall | Bool | false |  |  | 高级 | P3 | ⬜ |
| `role_base_wipe_speed` | Role-based wipe speed | Bool | true |  |  | 高级 |  | ⬜ |
| `scarf_angle_threshold` | Scarf application angle  | Int | 155 | 0~180 | ° | 高级 |  | ⬜ |
| `seam_placement_away_from_overhangs` | Seam placement away from | Bool | false |  |  | 高级 |  | ⬜ |
| `seam_slope_conditional` | Smart scarf seam applica | Bool | true |  |  | 高级 |  | ⬜ |
| `seam_slope_entire_loop` | Scarf around entire wall | Bool | false |  |  | 高级 |  | ⬜ |
| `seam_slope_gap` | Scarf slope gap | FloatOrPercent | 0, 0 | 0~ | mm/% | 高级 |  | ⬜ |
| `seam_slope_inner_walls` | Scarf joint for inner wa | Bool | true |  |  | 高级 |  | ⬜ |
| `seam_slope_min_length` | Scarf length | Float | 10 | 0~ |  | 高级 |  | ⬜ |
| `seam_slope_start_height` | Scarf start height | FloatOrPercent | 10, true | 0~ | mm/% | 高级 |  | ⬜ |
| `seam_slope_steps` | Scarf steps | Int | 10 | 1~ |  | 高级 |  | ⬜ |
| `seam_slope_type` | Scarf seam type | Enum | SeamScarfType: |  |  | 高级 |  | ⬜ |
| `slice_closing_radius` | Slice gap closing radius | Float | 0.049 | 0~ | mm | 高级 |  | ⬜ |
| `smooth_coefficient` | Smooth coefficient | Float | 80 | 0~ |  | 高级 |  | ⬜ |
| `smooth_speed_discontinuity_area` | Smooth speed discontinui | Bool | true |  |  | 高级 |  | ⬜ |
| `sparse_infill_line_width` | Sparse infill | Float | 0.4 | 0~ | mm | 高级 |  | ✅ |
| `support_line_width` | Support | Float | 0.4 | 0~ | mm | 高级 |  | ✅ |
| `thick_bridges` | Thick bridges | Bool | false |  |  | 高级 |  | ⬜ |
| `top_surface_line_width` | Top surface | Float | 0.4 | 0~ | mm | 高级 |  | ✅ |
| `wall_distribution_count` | Wall distribution count | Int | 1 | 1~ |  | 高级 |  | ⬜ |
| `wall_generator` | Wall generator | Enum | PerimeterGener |  |  | 高级 |  | ✅ |
| `wall_sequence` | Order of walls | Enum | WallSequence:: |  |  | 高级 | P1 | ⬜ |
| `wall_transition_angle` | Wall transitioning thres | Float | 10. | 1.~59. | ° | 高级 |  | ⬜ |
| `wall_transition_filter_deviation` | Wall transitioning filte | Percent | 25 | 0~ |  | 高级 |  | ⬜ |
| `wall_transition_length` | Wall transition length | Percent | 100 | 0~ |  | 高级 |  | ⬜ |
| `xy_contour_compensation` | X-Y contour compensation | Float | 0 |  | mm | 高级 | P1 | ⬜ |
| `xy_hole_compensation` | X-Y hole compensation | Float | 0 |  | mm | 高级 | P1 | ⬜ |
| `z_direction_outwall_speed_continuous` | Smoothing wall speed alo | Bool | false |  |  | 高级 |  | ⬜ |
| `detect_overhang_wall` | Detect overhang wall | Bool | true |  |  | 开发 |  | ⬜ |
| `initial_layer_flow_ratio` | Initial layer flow ratio | Float | 1 | 0~2 |  | 开发 |  | ⬜ |
| `interface_shells` | Interface shells | Bool | false |  |  | 开发 |  | ⬜ |
| `ironing_direction` | ironing direction | Float | 45 | 0~360 | ° | 开发 |  | ⬜ |
| `precise_outer_wall` | Precise wall | Bool | false |  |  | 开发 |  | ⬜ |
| `print_flow_ratio` | Object flow ratio | Float | 1 | 0.01~2 |  | 开发 |  | ⬜ |
| `seam_gap` | Seam gap | Percent | 15 | 0~ |  | 开发 |  | ⬜ |
| `top_solid_infill_flow_ratio` | Top surface flow ratio | Floats | 1 | 0~2 |  | 开发 |  | ⬜ |
| `wipe_speed` | Wipe speed | Percent | 80 | 0.01~ |  | 开发 |  | ⬜ |

### Strength（54 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `bottom_color_penetration_layers` | Bottom paint penetration | Int | 3 | 1~ |  | 简单 |  | ⬜ |
| `bottom_shell_layers` | Bottom shell layers | Int | 3 | 0~ |  | 简单 | P1 | ⬜ |
| `bottom_shell_thickness` | Bottom shell thickness | Float | 0. | 0~ | mm | 简单 | P1 | ⬜ |
| `bottom_surface_pattern` | Bottom surface pattern | Enum | ipRectilinear |  |  | 简单 | P1 | ⬜ |
| `fill_multiline` | Fill multiline | Int | 1 | 1~5 |  | 简单 |  | ⬜ |
| `infill_instead_top_bottom_surfaces` | Use infill instead of to | Bool | false |  |  | 简单 |  | ⬜ |
| `internal_solid_infill_pattern` | Internal solid infill pa | Enum | ipRectilinear |  |  | 简单 | P1 | ⬜ |
| `locked_skeleton_infill_pattern` | Skeleton infill pattern | Enum | ipZigZag |  |  | 简单 |  | ⬜ |
| `locked_skin_infill_pattern` | Skin infill pattern | Enum | ipCrossZag |  |  | 简单 |  | ⬜ |
| `sparse_infill_anchor_max` | Maximum length of sparse | FloatOrPercent | 20, false |  |  | 简单 | P1 | ⬜ |
| `sparse_infill_density` | Sparse infill density | Percent | 20 | 0~100 |  | 简单 |  | ✅ |
| `sparse_infill_pattern` | Sparse infill pattern | Enum | ipCubic |  |  | 简单 |  | ✅ |
| `top_color_penetration_layers` | Top paint penetration la | Int | 4 | 1~ |  | 简单 |  | ⬜ |
| `top_shell_layers` | Top shell layers | Int | 4 | 0~ |  | 简单 | P1 | ⬜ |
| `top_shell_thickness` | Top shell thickness | Float | 0.6 | 0~ | mm | 简单 | P1 | ⬜ |
| `top_surface_pattern` | Top surface pattern | Enum | ipRectilinear |  |  | 简单 | P1 | ⬜ |
| `wall_loops` | Wall loops | Int | 2 | 0~1000 |  | 简单 |  | ✅ |
| `alternate_extra_wall` | Alternate extra wall | Bool | false |  |  | 高级 |  | ⬜ |
| `bottom_surface_density` | Bottom surface density | Percent | 100 | 10~100 |  | 高级 |  | ⬜ |
| `bridge_angle` | Bridge direction | Float | 0. | 0~ | ° | 高级 |  | ⬜ |
| `conformal_hub_radius` | Center region radius | Float | 0 | 0~200 | mm | 高级 |  | ⬜ |
| `conformal_infill` | Conformal infill | Bool | false |  |  | 高级 |  | ⬜ |
| `conformal_link_flip_layers` | Reverse layers | Int | 0 | 0~1000 | layers | 高级 |  | ⬜ |
| `conformal_link_keep_layers` | Forward layers | Int | 1 | 0~1000 | layers | 高级 |  | ⬜ |
| `conformal_pole` | Radial center | Enum | ConformalPole: |  |  | 高级 |  | ⬜ |
| `conformal_ray_count` | Radial line count | Int | 0 | 0~1000 |  | 高级 |  | ⬜ |
| `conformal_stagger` | Layer stagger | Enum | ConformalStagg |  |  | 高级 |  | ⬜ |
| `detect_narrow_internal_solid_infill` | Detect narrow internal s | Bool | true |  |  | 高级 |  | ⬜ |
| `detect_thin_wall` | Detect thin wall | Bool | false |  |  | 高级 |  | ⬜ |
| `embedding_wall_into_infill` | Embedding the wall into  | Bool | false |  |  | 高级 |  | ⬜ |
| `ensure_vertical_shell_thickness` | Ensure vertical shell th | Enum | EnsureVertical |  |  | 高级 | P1 | ⬜ |
| `infill_combination` | Infill combination | Bool | false |  |  | 高级 |  | ⬜ |
| `infill_direction` | Infill direction | Float | 45 | 0~360 | ° | 高级 |  | ⬜ |
| `infill_lock_depth` | Infill lock depth | Float | 1.0 | 0~100 | mm | 高级 |  | ⬜ |
| `infill_rotate_step` | Infill rotate step | Float | 0 | 0~360 | ° | 高级 |  | ⬜ |
| `infill_shift_step` | Infill shift step | Float | 0.4 | 0~10 | mm | 高级 |  | ⬜ |
| `infill_wall_overlap` | Infill/Wall overlap | Percent | 15 |  |  | 高级 |  | ⬜ |
| `internal_bridge_support_thickness` | Internal bridge support  | Float | 0 | 0~2 | mm | 高级 |  | ⬜ |
| `minimum_sparse_infill_area` | Minimum sparse infill th | Float | 15 | 0~ | mm² | 高级 | P1 | ⬜ |
| `skeleton_infill_density` | Skeleton infill density | Percent | 15 | 0~100 |  | 高级 |  | ⬜ |
| `skeleton_infill_line_width` | Skeleton line width | Float | 0.4 | 0~ | mm | 高级 |  | ⬜ |
| `skin_infill_density` | Skin infill density | Percent | 15 | 0~100 |  | 高级 |  | ⬜ |
| `skin_infill_depth` | Skin infill depth | Float | 2.0 | 0~100 | mm | 高级 |  | ⬜ |
| `skin_infill_line_width` | Skin line width | Float | 0.4 | 0~ | mm | 高级 |  | ⬜ |
| `sparse_infill_acceleration` | Sparse infill | FloatsOrPercents | FloatOrPercent | 0~ | mm/s² or | 高级 |  | ⬜ |
| `sparse_infill_anchor` | Length of sparse infill  | FloatOrPercent | 400, true |  | mm or % | 高级 | P1 | ⬜ |
| `sparse_infill_lattice_angle_1` | Lattice angle 1 | Float | -45 | -75~75 | ° | 高级 |  | ⬜ |
| `sparse_infill_lattice_angle_2` | Lattice angle 2 | Float | 45 | -75~75 | ° | 高级 |  | ⬜ |
| `sub_top_surface_pattern` | Sub-top surface pattern | Enum | ipMonotonic |  |  | 高级 |  | ⬜ |
| `symmetric_infill_y_axis` | Symmetric infill y axis | Bool | false |  |  | 高级 |  | ⬜ |
| `top_surface_acceleration` | Top surface | Floats | 500 | 0~ |  | 高级 |  | ⬜ |
| `top_surface_density` | Top surface density | Percent | 100 | 0~100 |  | 高级 |  | ⬜ |
| `top_surface_jerk` | Top surface | Float | 9 | 0~ | mm/s | 高级 |  | ⬜ |
| `monotonic_travel_into_wall` | Monotonic line travel ex | Percent | 0.0 | 0~200 |  | 开发 |  | ⬜ |

### Support（72 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `brim_type` | Brim type | Enum | btAutoBrim |  |  | 简单 |  | ✅ |
| `brim_width` | Brim width | Float | 0. | 0~100 | mm | 简单 |  | ✅ |
| `enable_support` | Enable support | Bool | false |  |  | 简单 |  | ✅ |
| `support_buildplate_only` |   | Bool | false |  |  | 简单 |  | ⬜ |
| `support_filament` | Support/raft base | Int | 0 | 0~ |  | 简单 |  | ⬜ |
| `support_interface_filament` | Support/raft interface | Int | 0 | 0~ |  | 简单 |  | ⬜ |
| `support_interface_not_for_body` | Avoid interface filament | Bool | true |  |  | 简单 |  | ⬜ |
| `support_object_skip_flush` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `support_on_build_plate_only` | On build plate only | Bool | false |  |  | 简单 |  | ✅ |
| `support_pillar_diameter` |   | Float | 1.0 | 0~15 |   | 简单 |  | ⬜ |
| `support_points_density_relative` |   | Int | 100 | 0~ |   | 简单 |  | ⬜ |
| `support_points_minimal_distance` |   | Float | 1. | 0~ | mm | 简单 |  | ⬜ |
| `support_threshold_angle` | Threshold angle | Int | 30 | 1~90 | ° | 简单 |  | ✅ |
| `support_type` | Type | Enum | stNormalAuto |  |  | 简单 |  | ✅ |
| `bridge_no_support` | Don't support bridges | Bool | false |  |  | 高级 |  | ⬜ |
| `brim_object_gap` | Brim-object gap | Float | 0. | 0~2 | mm | 高级 |  | ✅ |
| `independent_support_layer_height` | Independent support laye | Bool | true |  |  | 高级 |  | ⬜ |
| `max_bridge_length` | Max bridge length | Float | 10 | 0~ | mm | 高级 |  | ⬜ |
| `raft_contact_distance` | Raft contact Z distance | Float | 0.1 | 0~ | mm | 高级 |  | ⬜ |
| `raft_expansion` | Raft expansion | Float | 1.5 | 0~ | mm | 高级 |  | ⬜ |
| `raft_first_layer_density` | Initial layer density | Percent | 90 | 10~100 |  | 高级 |  | ⬜ |
| `raft_first_layer_expansion` | Initial layer expansion | Float | -1 | -1~ | mm | 高级 |  | ⬜ |
| `raft_layers` | Raft layers | Int | 0 | 0~100 | layers | 高级 |  | ⬜ |
| `support_air_filtration` | Air filtration enhanceme | Bool | false |  |  | 高级 |  | ⬜ |
| `support_angle` | Pattern angle | Float | 0 | 0~359 | ° | 高级 |  | ⬜ |
| `support_base_diameter` |   | Float | 4.0 | 0~30 |   | 高级 |  | ⬜ |
| `support_base_height` |   | Float | 1.0 | 0~ |   | 高级 |  | ⬜ |
| `support_base_pattern` | Base pattern | Enum | smpDefault |  |  | 高级 |  | ⬜ |
| `support_base_pattern_spacing` | Base pattern spacing | Float | 2.5 | 0~ | mm | 高级 |  | ✅ |
| `support_base_safety_distance` |   | Float | 1 | 0~10 |   | 高级 |  | ⬜ |
| `support_bottom_z_distance` | Bottom Z distance | Float | 0.2 |  | mm | 高级 |  | ✅ |
| `support_cooling_filter` |  | Bool | false |  |  | 高级 |  | ⬜ |
| `support_critical_angle` |   | Float | 45 | 0~90 |   | 高级 |  | ⬜ |
| `support_critical_regions_only` | Support critical regions | Bool | false |  |  | 高级 |  | ⬜ |
| `support_expansion` | Normal Support expansion | Float | 0 |  | mm | 高级 |  | ✅ |
| `support_head_front_diameter` |   | Float | 0.4 | 0~ |   | 高级 |  | ⬜ |
| `support_head_penetration` |   | Float | 0.2 | 0~ |   | 高级 |  | ⬜ |
| `support_head_width` |   | Float | 1.0 | 0~20 |   | 高级 |  | ⬜ |
| `support_interface_bottom_layers` | Bottom interface layers | Int | 0 | -1~ | layers | 高级 |  | ⬜ |
| `support_interface_loop_pattern` | Interface use loop patte | Bool | false |  |  | 高级 |  | ⬜ |
| `support_interface_pattern` | Interface pattern | Enum | smipAuto |  |  | 高级 |  | ⬜ |
| `support_interface_spacing` | Top interface spacing | Float | 0.5 | 0~ | mm | 高级 |  | ✅ |
| `support_interface_top_layers` | Top interface layers | Int | 3 | 0~ | layers | 高级 |  | ✅ |
| `support_max_bridge_length` |   | Float | 15.0 | 0~ |   | 高级 |  | ⬜ |
| `support_max_bridges_on_pillar` |   | Int | 3 | 0~50 |  | 高级 |  | ⬜ |
| `support_max_pillar_link_distance` |   | Float | 10.0 | 0~ |   | 高级 |  | ⬜ |
| `support_object_elevation` |   | Float | 5.0 | 0~150 |   | 高级 |  | ⬜ |
| `support_object_first_layer_gap` | Support/object first lay | Float | 0.2 | 0~10 | mm | 高级 |  | ⬜ |
| `support_object_xy_distance` | Support/object xy distan | Float | 0.35 | 0~10 | mm | 高级 |  | ✅ |
| `support_pillar_connection_mode` |   | Enum | slapcmDynamic |  |  | 高级 |  | ⬜ |
| `support_pillar_widening_factor` |   | Float | 0.0 | 0~1 |  | 高级 |  | ⬜ |
| `support_remove_small_overhang` | Remove small overhangs | Bool | true |  |  | 高级 |  | ✅ |
| `support_small_pillar_diameter_percent` |   | Percent | 50 | 1~100 |   | 高级 |  | ⬜ |
| `support_style` | Style | Enum | smsDefault |  |  | 高级 |  | ✅ |
| `support_top_z_distance` | Top Z distance | Float | 0.2 | 0~ | mm | 高级 |  | ✅ |
| `top_z_overrides_xy_distance` | Z overrides X/Y | Bool | false |  |  | 高级 |  | ⬜ |
| `tree_support_branch_angle` | Branch angle | Float | 40. | 0~60 | ° | 高级 |  | ✅ |
| `tree_support_branch_diameter` | Branch diameter | Float | 5. | 1.0~10 | mm | 高级 |  | ✅ |
| `tree_support_branch_diameter_angle` | Branch diameter angle | Float | 5. | 0.0~15 | ° | 高级 |  | ⬜ |
| `tree_support_branch_distance` | Branch distance | Float | 5. | 1.0~10 | mm | 高级 |  | ⬜ |
| `tree_support_wall_count` | Support wall loops | Int | -1 | -1~2 |  | 高级 |  | ✅ |
| `enable_support_ironing` | Enable ironing support i | Bool | false |  |  | 开发 |  | ⬜ |
| `enforce_support_layers` | Enforce support for the  | Int | 0 | 0~5000 | layers | 开发 |  | ⬜ |
| `support_bottom_interface_spacing` | Bottom interface spacing | Float | 0.5 | 0~ | mm | 开发 |  | ⬜ |
| `support_chamber_temp_control` | Support control chamber  | Bool | false |  |  | 开发 |  | ⬜ |
| `support_fast_purge_mode` | Support fast purge mode | Bool | false |  |  | 开发 |  | ⬜ |
| `support_ironing_direction` | Support ironing directio | Float | 0 | 0~360 | ° | 开发 |  | ⬜ |
| `support_ironing_flow` | Support ironing flow | Percent | 10 | 0~100 |  | 开发 |  | ⬜ |
| `support_ironing_inset` | Support ironing inset | Float | 0 | 0~100 | mm | 开发 |  | ⬜ |
| `support_ironing_pattern` | Support ironing pattern | Enum | ipRectilinear |  |  | 开发 |  | ⬜ |
| `support_ironing_spacing` | Support ironing line spa | Float | 0.1 | 0~1 | mm | 开发 |  | ⬜ |
| `support_ironing_speed` | Support ironing speed | Float | 20 | 0~ | mm/s | 开发 |  | ⬜ |

### Speed（43 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `additional_cooling_fan_speed` | Fan speed | Ints | 0 | 0~100 |  | 简单 |  | ⬜ |
| `circle_compensation_speed` | Circle Compensation Spee | Floats | 200 | 0~ | mm/s | 简单 |  | ⬜ |
| `complete_print_exhaust_fan_speed` | Fan speed | Ints | 80 | 0~100 |  | 简单 |  | ⬜ |
| `during_print_exhaust_fan_speed` | Fan speed | Ints | 60 | 0~100 |  | 简单 |  | ⬜ |
| `fan_max_speed` | Fan speed | Ints | 100 | 0~100 |  | 简单 | P4 | ⬜ |
| `fan_min_speed` | Fan speed | Ints | 20 | 0~100 |  | 简单 | P4 | ⬜ |
| `first_x_layer_fan_speed` | Fan speed | Floats | 0 | 0~100 |  | 简单 |  | ⬜ |
| `first_x_layer_part_fan_speed` | Fan speed | Ints | 0 | 0~100 |  | 简单 |  | ⬜ |
| `prime_tower_lift_speed` |  | Float | 90. |  |  | 简单 |  | ⬜ |
| `bridge_speed` | Bridge | Floats | 25 | 0~ | mm/s | 高级 | P2 | ⬜ |
| `deretraction_speed` | Deretraction Speed | Floats | 0. |  | mm/s | 高级 |  | ⬜ |
| `enable_height_slowdown` | Slow down by height | Bools | false |  |  | 高级 |  | ⬜ |
| `enable_overhang_speed` | Slow down for overhang | Bools | true |  |  | 高级 |  | ⬜ |
| `gap_infill_speed` | Gap infill | Floats | 30 | 0~ | mm/s | 高级 |  | ⬜ |
| `inner_wall_speed` | Inner wall | Floats | 60 | 0~ | mm/s | 高级 | P2 | ⬜ |
| `internal_solid_infill_speed` | Internal solid infill | Floats | 100 | 0~ | mm/s | 高级 | P2 | ⬜ |
| `ironing_fan_speed` | Ironing fan speed | Ints | -1 | -1~100 |  | 高级 |  | ⬜ |
| `material_print_speed` |   | Enum | slamsFast |  |  | 高级 |  | ⬜ |
| `outer_wall_speed` | Outer wall | Floats | 60 | 0~ | mm/s | 高级 | P2 | ⬜ |
| `overhang_1_4_speed` |  | Floats | 0 | 0~ | mm/s | 高级 |  | ⬜ |
| `overhang_2_4_speed` |  | Floats | 0 | 0~ | mm/s | 高级 |  | ⬜ |
| `overhang_3_4_speed` |  | Floats | 0 | 0~ | mm/s | 高级 |  | ⬜ |
| `overhang_4_4_speed` |  | Floats | 0 | 0~ | mm/s | 高级 |  | ⬜ |
| `overhang_fan_speed` | Fan speed for overhang | Ints | 100 | 0~100 |  | 高级 | P4 | ⬜ |
| `overhang_totally_speed` | 100% | Floats | 10 | 0~ | mm/s | 高级 |  | ⬜ |
| `override_process_overhang_speed` | Override overhang speed | Bools | {false |  |  | 高级 |  | ⬜ |
| `prime_tower_max_speed` | Max speed | Float | 90. | 10~ | mm/s | 高级 |  | ⬜ |
| `retraction_speed` | Retraction Speed | Floats | 30. |  | mm/s | 高级 | P3 | ⬜ |
| `slow_down_min_speed` | Min print speed | Floats | 10. | 0~ | mm/s | 高级 |  | ⬜ |
| `slowdown_end_acc` | Acceleration at ending h | Floats | 100000. | 0~ | mm/s² | 高级 |  | ⬜ |
| `slowdown_end_height` | Ending height | Floats | 400 | 0~ | mm | 高级 |  | ⬜ |
| `slowdown_end_speed` | Speed at ending height | Floats | 1000. | 0~ | mm/s | 高级 |  | ⬜ |
| `slowdown_start_acc` | Acceleration at starting | Floats | 100000. | 0~ | mm/s² | 高级 |  | ⬜ |
| `slowdown_start_height` | Starting height | Floats | 0 | 0~ | mm | 高级 |  | ⬜ |
| `slowdown_start_speed` | Speed at starting height | Floats | 1000. | 0~ | mm/s | 高级 |  | ⬜ |
| `small_perimeter_speed` | Small perimeters | FloatsOrPercents | FloatOrPercent | 0~ | mm/s or  | 高级 |  | ⬜ |
| `small_perimeter_threshold` | Small perimeter threshol | Floats | 0 | 0~ | mm | 高级 |  | ⬜ |
| `sparse_infill_speed` | Sparse infill | Floats | 100 | 0~ | mm/s | 高级 | P2 | ⬜ |
| `support_interface_speed` | Support interface | Floats | 80 | 1~ | mm/s | 高级 | P2 | ⬜ |
| `support_speed` | Support | Floats | 80 | 0~ | mm/s | 高级 | P2 | ⬜ |
| `top_surface_speed` | Top surface | Floats | 100 | 0~ | mm/s | 高级 | P2 | ⬜ |
| `travel_speed` | Travel | Floats | 120 | 1~ | mm/s | 高级 | P2 | ✅ |
| `vertical_shell_speed` | Vertical shell speed | FloatsOrPercents | FloatOrPercent | 0~ | mm/s or  | 高级 |  | ⬜ |

### Adhesion（4 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `skirt_height` | Skirt height | Int | 1 | ~10000 | layers | 简单 |  | ⬜ |
| `skirt_loops` | Skirt loops | Int | 1 | 0~10 |  | 简单 |  | ⬜ |
| `skirt_distance` | Skirt distance | Float | 2 | 0~55 | mm | 开发 |  | ⬜ |
| `skirt_per_object` | Skirt per object | Bool | true |  |  | 开发 |  | ⬜ |

### Cooling（21 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `additional_fan_full_speed_layer` | Full fan speed at layer | Ints | 0 | 0~100000 |  | 简单 |  | ⬜ |
| `close_additional_fan_first_x_layers` | For the first | Ints | 1 | 0~100000 | layers | 简单 |  | ⬜ |
| `close_fan_the_first_x_layers` | For the first | Ints | 1 | 0~100000 | layers | 简单 | P4 | ⬜ |
| `cool_plate_temp` | Other layers | Ints | 35 | 0~120 |  | 简单 |  | ⬜ |
| `cool_plate_temp_initial_layer` | Initial layer | Ints | 35 | 0~120 |  | 简单 |  | ⬜ |
| `enable_overhang_bridge_fan` | Force cooling for overha | Bools | true |  |  | 简单 | P4 | ⬜ |
| `fan_cooling_layer_time` | Layer time | Ints | 60 | 0~1000 | s | 简单 | P4 | ⬜ |
| `full_fan_speed_layer` | Full fan speed at layer | Ints | 0 | 0~100000 |  | 简单 | P4 | ⬜ |
| `hotend_cooling_rate` |  | Floats | 2 |  |  | 简单 |  | ⬜ |
| `reduce_fan_stop_start_freq` | Keep fan always on | Bools | false |  |  | 简单 |  | ⬜ |
| `slow_down_for_layer_cooling` | Slow printing down for b | Bools | true |  |  | 简单 | P4 | ⬜ |
| `cooling_filter_enabled` | Use cooling filter | Bool | false |  |  | 高级 |  | ⬜ |
| `elefant_foot_min_width` |   | Float | 0.2 | 0~ |   | 高级 |  | ⬜ |
| `no_slow_down_for_cooling_on_outwalls` | Don't slow down outer wa | Bools | false |  |  | 高级 |  | ⬜ |
| `overhang_fan_threshold` | Cooling overhang thresho | Enums | (int |  |  | 高级 |  | ⬜ |
| `overhang_threshold_participating_cooling` | Overhang threshold for p | Enums | (int |  |  | 高级 |  | ⬜ |
| `pre_start_fan_time` | Pre start fan time | Floats | 0.0 | 0.~5. | s | 高级 |  | ⬜ |
| `auxiliary_fan` | Auxiliary part cooling f | Bool | false |  |  | 开发 |  | ⬜ |
| `cooling_perimeter_transition_distance` | Perimeter transition dis | Floats | 10.0 | 0~50 | mm | 开发 |  | ⬜ |
| `cooling_slowdown_logic` | Cooling slowdown logic | Enums | (int |  |  | 开发 |  | ⬜ |
| `fan_direction` | Fan direction | Enum | fdUndefine |  |  | 开发 |  | ⬜ |

### Retraction（13 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `retraction_length` | Length | Floats | 0.8 |  | mm | 简单 | P3 | ⬜ |
| `z_hop` | Z hop when retract | Floats | 0.4 | 0~5 | mm | 简单 | P3 | ⬜ |
| `retraction_distances_when_ec` | Retraction distance when | Floats | 10 | 0~10 | mm | 高级 |  | ⬜ |
| `retraction_minimum_travel` | Travel distance threshol | Floats | 2. |  | mm | 高级 | P3 | ⬜ |
| `wipe` | Wipe while retracting | Bools | false |  |  | 高级 | P3 | ⬜ |
| `wipe_distance` | Wipe Distance | Floats | 2. | 0~ | mm | 高级 | P3 | ⬜ |
| `wipe_tower_bridging` | Maximal bridging distanc | Float | 10. |  | mm | 高级 |  | ⬜ |
| `z_hop_types` | Z Hop Type | Enums | ZHopType::zhtS |  |  | 高级 | P3 | ⬜ |
| `retraction_distances_when_cut` | Retraction distance when | Floats | 18 | 10~18 |  | 开发 |  | ⬜ |
| `wipe_tower_no_sparse_layers` | No sparse layers (experi | Bool | false |  |  | 开发 |  | ⬜ |
| `wipe_tower_rotation_angle` | Wipe tower rotation angl | Float | 0. |  | ° | 开发 |  | ⬜ |
| `wipe_tower_x` | Position X | Floats | 15. |  | mm | 开发 |  | ⬜ |
| `wipe_tower_y` | Position Y | Floats | 220. |  | mm | 开发 |  | ⬜ |

### Others（13 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `fuzzy_skin` | Fuzzy Skin | Enum | FuzzySkinType: |  |  | 简单 |  | ⬜ |
| `fuzzy_skin_first_layer` | Apply fuzzy skin to firs | Bool | false |  |  | 简单 |  | ⬜ |
| `fuzzy_skin_mode` | Fuzzy skin generator mod | Enum | FuzzySkinMode: |  |  | 简单 |  | ⬜ |
| `fuzzy_skin_noise_type` | Fuzzy skin noise type | Enum | NoiseType::Cla |  |  | 简单 |  | ⬜ |
| `fuzzy_skin_point_distance` | Fuzzy skin point distanc | Float | 0.8 | 0~5 | mm | 简单 |  | ⬜ |
| `fuzzy_skin_thickness` | Fuzzy skin thickness | Float | 0.3 | 0~1 | mm | 简单 |  | ⬜ |
| `modifier_ignore_infill` | Ignore infill settings | Bool | false |  |  | 简单 |  | ⬜ |
| `periodic_modifier` | Periodic modifier | Bool | false |  |  | 简单 |  | ⬜ |
| `periodic_modifier_apply_layers` | Apply for | Int | 1 | 1~1000 | layers | 简单 |  | ⬜ |
| `periodic_modifier_skip_layers` | Skip for | Int | 1 | 0~1000 | layers | 简单 |  | ⬜ |
| `fuzzy_skin_octaves` | Fuzzy skin noise octaves | Int | 4 | 1~10 |  | 高级 |  | ⬜ |
| `fuzzy_skin_persistence` | Fuzzy skin noise persist | Float | 0.5 | 0.01~1 |  | 高级 |  | ⬜ |
| `fuzzy_skin_scale` | Fuzzy skin feature size | Float | 1.0 | 0.1~500 | mm | 高级 |  | ⬜ |

### Advanced（8 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `interlocking_beam` | Use beam interlocking | Bool | false |  |  | 高级 |  | ⬜ |
| `interlocking_beam_layer_count` | Interlocking beam layers | Int | 2 | 1~ |  | 高级 |  | ⬜ |
| `interlocking_beam_width` | Interlocking beam width | Float | 0.8 | 0.01~ | mm | 高级 |  | ⬜ |
| `interlocking_boundary_avoidance` | Interlocking boundary av | Int | 2 | 0~ |  | 高级 |  | ⬜ |
| `interlocking_depth` | Interlocking depth | Int | 2 | 1~ |  | 高级 |  | ⬜ |
| `interlocking_orientation` | Interlocking direction | Float | 22.5 | 0~360 | ° | 高级 |  | ⬜ |
| `mmu_segmented_region_interlocking_depth` | Interlocking depth of a  | Float | 0. | 0~ | mm | 高级 |  | ⬜ |
| `mmu_segmented_region_max_width` | Maximum width of a segme | Float | 0. | 0~ | mm | 高级 |  | ⬜ |

### Machine limits（15 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `machine_max_acceleration_extruding` |  | Floats | 1500., 1250. | 0~ |  | 简单 |  | ⬜ |
| `machine_max_acceleration_retracting` |  | Floats | 1500., 1250. | 0~ |  | 简单 |  | ⬜ |
| `has_scarf_joint_seam` |  | Bool | false | 0~ | mm/s | 高级 |  | ⬜ |
| `machine_end_gcode` | End G-code | String | "M104 S0 ; tur |  |  | 高级 |  | ⬜ |
| `machine_hotend_change_time` | Hotend change time | Float | 0.0 | 0~ | s | 高级 |  | ⬜ |
| `machine_load_filament_time` | Filament load time | Float | 0.0 | 0~ | s | 高级 |  | ⬜ |
| `machine_pause_gcode` | Pause G-code | String | "" |  |  | 高级 |  | ⬜ |
| `machine_start_gcode` | Start G-code | String | "G28 ; home al |  |  | 高级 |  | ⬜ |
| `machine_switch_extruder_time` | Extruder switch time | Float | 5 | 0~ | s | 高级 |  | ⬜ |
| `machine_unload_filament_time` | Filament unload time | Float | 0.0 | 0~ | s | 高级 |  | ⬜ |
| `machine_max_acceleration_travel` |  | Floats | 1500., 1250. | 0~ |  | 开发 |  | ⬜ |
| `machine_max_printed_mass` |  | Float | 0 | 0~ | g | 开发 |  | ⬜ |
| `machine_min_extruding_rate` |  | Floats | 0., 0. | 0~ | mm/s | 开发 |  | ⬜ |
| `machine_min_travel_rate` |  | Floats | 0., 0. | 0~ | mm/s | 开发 |  | ⬜ |
| `machine_prepare_compensation_time` |  | Float | 260 |  |  | 开发 |  | ⬜ |

### G-code（2 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `gcode_flavor` | G-code flavor | Enum | gcfMarlinLegac |  |  | 高级 |  | ✅ |
| `gcode_add_line_number` | Add line number | Bool | 0 |  |  | 开发 |  | ⬜ |

### Filament（73 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `filament_dev_ams_drying_ams_limitations` |  | Strings | "" |  |  | 简单 |  | ⬜ |
| `filament_dev_ams_drying_heat_distortion_temperature` |  | Floats | 0 |  |  | 简单 |  | ⬜ |
| `filament_dev_ams_drying_temperature` |  | Floats | 0 |  |  | 简单 |  | ⬜ |
| `filament_dev_ams_drying_time` |  | Floats | 0 |  |  | 简单 |  | ⬜ |
| `filament_dev_chamber_drying_bed_temperature` |  | Floats | 0 |  |  | 简单 |  | ⬜ |
| `filament_dev_chamber_drying_time` |  | Floats | 0 |  |  | 简单 |  | ⬜ |
| `filament_dev_drying_cooling_temperature` |  | Floats | 0 |  |  | 简单 |  | ⬜ |
| `filament_dev_drying_softening_temperature` |  | Floats | 0 |  |  | 简单 |  | ⬜ |
| `filament_diameter` | Diameter | Floats | 1.75 | 0~ | mm | 简单 |  | ✅ |
| `filament_extruder_id` |  | Ints | 1 |  |  | 简单 |  | ⬜ |
| `filament_extruder_variant` |  | Strings | "Direct Drive  |  |  | 简单 |  | ⬜ |
| `filament_ids` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `filament_multi_colour` |  | Strings | "" |  |  | 简单 |  | ⬜ |
| `filament_prime_volume` | Filament change | Floats | 45. | 1.0~ | mm³ | 简单 |  | ⬜ |
| `filament_prime_volume_nc` | Hotend change | Floats | 60. | 1.0~ | mm³ | 简单 |  | ⬜ |
| `filament_self_index` |  | Ints | 1 |  |  | 简单 |  | ⬜ |
| `filament_settings_id` |  | Strings | "" |  |  | 简单 |  | ⬜ |
| `filament_type` | Type | Strings | "PLA" |  |  | 简单 |  | ✅ |
| `filament_velocity_adaptation_factor` | Velocity Adaptation Fact | Floats | 1.0 | 0~ |  | 简单 |  | ⬜ |
| `filament_adaptive_volumetric_speed` | Adaptive volumetric spee | Bools | false |  |  | 高级 |  | ⬜ |
| `filament_change_length` | Extruder change | Floats | 10 | 0~ | mm | 高级 |  | ⬜ |
| `filament_change_length_nc` | Hotend change | Floats | 10 | 0~ | mm | 高级 |  | ⬜ |
| `filament_cost` | Price | Floats | 0. | 0~ | money/kg | 高级 |  | ✅ |
| `filament_density` | Density | Floats | 0. | 0~ | g/cm³ | 高级 |  | ✅ |
| `filament_end_gcode` | End G-code | Strings | " " |  |  | 高级 |  | ⬜ |
| `filament_flow_ratio` | Flow ratio | Floats | 1. | ~2 |  | 高级 |  | ✅ |
| `filament_flush_temp` | Flush temperature | Ints | 0 | 0~ |  | 高级 |  | ⬜ |
| `filament_flush_temp_fast` | Flush temperature | Ints | 0 | 0~ |  | 高级 |  | ⬜ |
| `filament_flush_volumetric_speed` | Flush volumetric speed | Floats | 0 | 0~200 | mm³/s | 高级 |  | ⬜ |
| `filament_map_mode` | filament mapping mode | Enum | fmmAutoForFlus |  |  | 高级 |  | ⬜ |
| `filament_max_volumetric_speed` | Max volumetric speed | Floats | 2. | 0~200 | mm³/s | 高级 |  | ⬜ |
| `filament_metal_stickiness` | Metal stickiness | Enums | fmsNone |  |  | 高级 |  | ⬜ |
| `filament_notes` | Filament notes | String | "" |  |  | 高级 |  | ⬜ |
| `filament_pre_cooling_temperature` | Extruder change | Ints | 0 | 0~ |  | 高级 |  | ⬜ |
| `filament_pre_cooling_temperature_nc` | Hotend change | Ints | 0 | 0~ |  | 高级 |  | ⬜ |
| `filament_ramming_travel_time` | Extruder change | Floats | 0 | 0~ |  | 高级 |  | ⬜ |
| `filament_ramming_travel_time_nc` | Hotend change | Floats | 0 | 0~ |  | 高级 |  | ⬜ |
| `filament_ramming_volumetric_speed` | Extruder change | Floats | -1 | -1~200 | mm³/s | 高级 |  | ⬜ |
| `filament_ramming_volumetric_speed_nc` | Hotend change | Floats | -1 | -1~200 | mm³/s | 高级 |  | ⬜ |
| `filament_scarf_gap` | Scarf slope gap | FloatsOrPercents | FloatOrPercent | 0~ | mm/% | 高级 |  | ⬜ |
| `filament_scarf_height` | Scarf start height | FloatsOrPercents | FloatOrPercent | 0~ | mm/% | 高级 |  | ⬜ |
| `filament_scarf_length` | Scarf length | Floats | 10 | 0~ |  | 高级 |  | ⬜ |
| `filament_scarf_seam_type` | Scarf seam type | Enums | 0 |  |  | 高级 |  | ⬜ |
| `filament_shrink` | Shrinkage | Percents | 100 | 10~ | % | 高级 |  | ⬜ |
| `filament_start_gcode` | Start G-code | Strings | " " |  |  | 高级 |  | ⬜ |
| `filament_vendor` | Vendor | Strings | L("(Undefined |  |  | 高级 |  | ⬜ |
| `filament_adhesiveness_category` | Adhesiveness Category | Ints | 0 | 0~ |  | 开发 |  | ⬜ |
| `filament_colour` | Color | Strings | "#00AE42" |  |  | 开发 |  | ⬜ |
| `filament_colour_type` | Required nozzle HRC | Strings | "1" | 0~500 |  | 开发 |  | ⬜ |
| `filament_cooling_before_tower` | Wipe tower cooling | Floats | 10 |  |  | 开发 |  | ⬜ |
| `filament_extruder_compatibility` | Filament-extruder compat | Ints | 0 |  |  | 开发 |  | ⬜ |
| `filament_is_mixed` | Is mixed filament | Bools | false |  |  | 开发 |  | ⬜ |
| `filament_is_support` | Support material | Bools | false |  |  | 开发 |  | ⬜ |
| `filament_map` | Filament map to extruder | Ints | 1 |  |  | 开发 |  | ⬜ |
| `filament_map_2` |  | Ints | 1 |  |  | 开发 |  | ⬜ |
| `filament_minimal_purge_on_wipe_tower` | Minimal purge on wipe to | Floats | 15. | 0~ | mm³ | 开发 |  | ⬜ |
| `filament_mixed_components` | Mixed filament component | Strings | "" |  |  | 开发 |  | ⬜ |
| `filament_mixed_gradient` | Mixed filament gradient | Bools | false |  |  | 开发 |  | ⬜ |
| `filament_mixed_gradient_curve` | Mixed filament gradient  | Strings | "" |  |  | 开发 |  | ⬜ |
| `filament_mixed_gradient_per_part` | Mixed filament per-part  | Bools | false |  |  | 开发 |  | ⬜ |
| `filament_mixed_gradient_range` | Mixed filament gradient  | Strings | "" |  |  | 开发 |  | ⬜ |
| `filament_mixed_sublayer_ratios` | Mixed filament sublayer  | Strings | "" |  |  | 开发 |  | ⬜ |
| `filament_nozzle_map` |  | Ints | 1 |  |  | 开发 |  | ⬜ |
| `filament_preheat_temperature_delta` | Preheat temperature delt | Floats | 0 |  |  | 开发 |  | ⬜ |
| `filament_printable` | Filament printable | Ints | 3 |  |  | 开发 |  | ⬜ |
| `filament_retract_length_nc` | length when change hoten | Floats | 10. | 0~18 | mm | 开发 |  | ⬜ |
| `filament_soluble` | Soluble material | Bools | false |  |  | 开发 |  | ⬜ |
| `filament_tower_interface_pre_extrusion_dist` | Interface layer pre-extr | Floats | 10. | 0~ | mm | 开发 |  | ⬜ |
| `filament_tower_interface_pre_extrusion_length` | Interface layer pre-extr | Floats | 0. | 0~ | mm | 开发 |  | ⬜ |
| `filament_tower_interface_print_temp` | Interface layer print te | Ints | -1 | -1~ | °C | 开发 |  | ⬜ |
| `filament_tower_interface_purge_volume` | Interface layer purge le | Floats | 20. | 0~ | mm | 开发 |  | ⬜ |
| `filament_tower_ironing_area` | Tower ironing area | Floats | 4. | 0~ | mm² | 开发 |  | ⬜ |
| `filament_volume_map` |  | Ints | (int |  |  | 开发 |  | ⬜ |

### Extruders（4 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `solid_infill_filament` | Solid infill | Int | 0 | 0~ |  | 高级 |  | ✅ |
| `sparse_infill_filament` | Sparse infill filament | Int | 0 | 0~ |  | 高级 |  | ✅ |
| `wall_filament` | Walls | Int | 0 | 0~ |  | 高级 |  | ✅ |
| `extruder` | Extruder | Int |  | 0~ |  | 开发 |  | ⬜ |

### Flush options（3 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `flush_into_infill` | Flush into objects' infi | Bool | false |  |  | 简单 |  | ⬜ |
| `flush_into_objects` | Flush into this object | Bool | false |  |  | 简单 |  | ⬜ |
| `flush_into_support` | Flush into objects' supp | Bool | true |  |  | 简单 |  | ⬜ |

### Other（1 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `slicing_mode` | Slicing Mode | Enum | SlicingMode::R |  |  | 高级 |  | ⬜ |

### Others / Internal（341 项）

| 键名 | 显示名 | 类型 | 默认值 | 范围 | 单位 | 等级 | 阶段 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `activate_air_filtration` | Activate air filtration | Bools | false |  |  | 简单 |  | ⬜ |
| `align_xy` | Align XY | Point | Vec2d(100,100 |  |  | 简单 |  | ⬜ |
| `allow_mix_temp` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `allow_multicolor_oneplate` |  | Bool | true |  |  | 简单 |  | ⬜ |
| `allow_newer_file` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `allow_rotations` |  | Bool | true |  |  | 简单 |  | ⬜ |
| `arrange` |  | Int | 0 |  |  | 简单 |  | ⬜ |
| `assemble` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `autosave` | Autosave | String |  |  |  | 简单 |  | ⬜ |
| `avoid_extrusion_cali_region` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `bed_heat_soak_area` |  | Points |  |  |  | 简单 |  | ⬜ |
| `bottle_cost` |   | Float | 0.0 | 0~ |   | 简单 |  | ⬜ |
| `bottle_volume` |   | Float | 1000.0 | 50~ |   | 简单 |  | ⬜ |
| `bottle_weight` |   | Float | 1.0 | 0~ |   | 简单 |  | ⬜ |
| `camera_view` |  | Int | 0 |  |  | 简单 |  | ⬜ |
| `center` | Center | Point | Vec2d(100,100 |  |  | 简单 |  | ⬜ |
| `chamber_temperatures` | Chamber temperature | Ints | 0 | 0~80 |  | 简单 |  | ⬜ |
| `check_preset` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `clone_objects` |  | Ints |  |  |  | 简单 |  | ⬜ |
| `compatible_machine_expression_group` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `compatible_process_expression_group` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `config_compatibility` | Forward-compatibility ru | Enum | ForwardCompati |  |  | 简单 |  | ⬜ |
| `convert_unit` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `copy` | Copy | Int | 1 | 1~ |  | 简单 |  | ⬜ |
| `counter_coef_1` | Counter Coef 1 | Floats | 0 |  |  | 简单 |  | ⬜ |
| `counter_coef_2` | Contour Coef 2 | Floats | 0.025 |  |  | 简单 |  | ⬜ |
| `counter_coef_3` | Contour Coef 3 | Floats | -0.11 |  | mm | 简单 |  | ⬜ |
| `counter_limit_max` | Contour limit max | Floats | 0.05 |  | mm | 简单 |  | ⬜ |
| `counter_limit_min` | Contour limit min | Floats | -0.04 |  | mm | 简单 |  | ⬜ |
| `curr_bed_type` | Bed type | Enum | btPC |  |  | 简单 |  | ✅ |
| `cut` | Cut | Float | 0 |  |  | 简单 |  | ⬜ |
| `cut_grid` | Cut | Float |  |  |  | 简单 |  | ⬜ |
| `cut_x` | Cut | Float | 0 |  |  | 简单 |  | ⬜ |
| `cut_y` | Cut | Float | 0 |  |  | 简单 |  | ⬜ |
| `datadir` |  | String |  |  |  | 简单 |  | ⬜ |
| `debug` |  | Int | 1 | 0~ |  | 简单 |  | ⬜ |
| `default_filament_profile` | Default filament profile | Strings |  |  |  | 简单 |  | ⬜ |
| `default_print_profile` | Default process profile | String |  |  |  | 简单 |  | ⬜ |
| `default_sla_material_profile` |   | String |  |  |  | 简单 |  | ⬜ |
| `default_sla_print_profile` |   | String |  |  |  | 简单 |  | ⬜ |
| `diameter_limit` | Diameter limit | Floats | 50 |  | mm | 简单 |  | ⬜ |
| `different_settings_to_system` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `display_height` |   | Float | 68. | 1~ |  | 简单 |  | ⬜ |
| `display_pixels_x` |  | Int | 2560 | 100~ |  | 简单 |  | ⬜ |
| `display_pixels_y` |  | Int | 1440 | 100~ |  | 简单 |  | ⬜ |
| `display_width` |   | Float | 120. | 1~ |  | 简单 |  | ⬜ |
| `downward_check` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `downward_settings` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `duplicate_grid` | Duplicate by grid | Point |  |  |  | 简单 |  | ⬜ |
| `enable_filament_dynamic_map` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `enable_pre_heating` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `enable_pressure_advance` | Enable pressure advance | Bools | false |  |  | 简单 |  | ⬜ |
| `enable_prime_tower` | Enable | Bool | false |  |  | 简单 |  | ⬜ |
| `enable_timelapse` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `eng_plate_temp` | Other layers | Ints | 45 | 0~120 |  | 简单 |  | ⬜ |
| `eng_plate_temp_initial_layer` | Initial layer | Ints | 45 | 0~120 |  | 简单 |  | ⬜ |
| `ensure_on_bed` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `estimate_mode` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `export_3mf` |  | String | "output.3mf" |  |  | 简单 |  | ⬜ |
| `export_amf` | Export AMF | Bool | false |  |  | 简单 |  | ⬜ |
| `export_gcode` | Export G-code | Bool | false |  |  | 简单 |  | ⬜ |
| `export_obj` | Export OBJ | Bool | false |  |  | 简单 |  | ⬜ |
| `export_png` |  | Int | -1 |  |  | 简单 |  | ⬜ |
| `export_settings` |  | String | "output.json" |  |  | 简单 |  | ⬜ |
| `export_sla` | Export SLA | Bool | false |  |  | 简单 |  | ⬜ |
| `export_slicedata` |  | String | "cached_data" |  |  | 简单 |  | ⬜ |
| `export_stl` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `export_stls` |  | String | "stl_path" |  |  | 简单 |  | ⬜ |
| `export_svg` | Export SVG | Bool | false |  |  | 简单 |  | ⬜ |
| `exposure_time` |   | Float | 10 | 0~ |   | 简单 |  | ⬜ |
| `extruder_ams_count` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `extruder_nozzle_stats` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `extruder_nozzle_stats_new` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `extruder_variant_list` |  | Strings | "Direct Drive  |  |  | 简单 |  | ⬜ |
| `farthest_point_timelapse` | Farthest point timelapse | Bool | false |  |  | 简单 |  | ⬜ |
| `first_layer_print_sequence` | First layer print sequen | Ints | 0 | 0~16 |  | 简单 |  | ⬜ |
| `flush_multiplier` | Flush multiplier | Floats | 1.0 |  |  | 简单 |  | ⬜ |
| `flush_multiplier_fast` | Flush multiplier (Fast m | Floats | 1.2 |  |  | 简单 |  | ⬜ |
| `flush_volumes_matrix` | Purging volumes | Floats | 0.f, 280.f, 28 |  |  | 简单 |  | ⬜ |
| `flush_volumes_vector` |  | Floats | 140.f, 140.f,  |  |  | 简单 |  | ⬜ |
| `gcodeviewer` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `group_algo_with_time` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `has_filament_switcher` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `help` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `help_fff` | Help (FFF options) | Bool | false |  |  | 简单 |  | ⬜ |
| `help_sla` | Help (SLA options) | Bool | false |  |  | 简单 |  | ⬜ |
| `hole_coef_1` | Hole Coef 1 | Floats | 0 |  |  | 简单 |  | ⬜ |
| `hole_coef_2` | Hole Coef 2 | Floats | -0.025 |  |  | 简单 |  | ⬜ |
| `hole_coef_3` | Hole Coef 3 | Floats | 0.28 |  | mm | 简单 |  | ⬜ |
| `hole_limit_max` | Hole limit max | Floats | 0.25 |  | mm | 简单 |  | ⬜ |
| `hole_limit_min` | Hole limit min | Floats | 0.08 |  | mm | 简单 |  | ⬜ |
| `hollowing_enable` |   | Bool | false |  |  | 简单 |  | ⬜ |
| `hollowing_min_thickness` |   | Float | 3. | 1~10 |   | 简单 |  | ⬜ |
| `hot_plate_temp` | Other layers | Ints | 45 | 0~120 |  | 简单 |  | ⬜ |
| `hot_plate_temp_initial_layer` | Initial layer | Ints | 45 | 0~120 |  | 简单 |  | ⬜ |
| `hotend_heating_rate` |  | Floats | 2 |  |  | 简单 |  | ⬜ |
| `ignore_nonexistent_config` | Ignore non-existent conf | Bool |  |  |  | 简单 |  | ⬜ |
| `info` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `inherits` | Inherits profile | String |  |  |  | 简单 |  | ⬜ |
| `inherits_group` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `initial_exposure_time` |   | Float | 15 | 0~ |   | 简单 |  | ⬜ |
| `load` | Load config file | Strings |  |  |  | 简单 |  | ⬜ |
| `load_assemble_list` |  | String |  |  |  | 简单 |  | ⬜ |
| `load_custom_gcodes` |  | String |  |  |  | 简单 |  | ⬜ |
| `load_defaultfila` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `load_filament_ids` |  | Ints |  |  |  | 简单 |  | ⬜ |
| `load_filaments` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `load_settings` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `load_slicedata` |  | Strings | "cached_data" |  |  | 简单 |  | ⬜ |
| `makerlab_name` |  | String |  |  |  | 简单 |  | ⬜ |
| `makerlab_version` |  | String |  |  |  | 简单 |  | ⬜ |
| `master_extruder_id` |  | Int | 1 |  |  | 简单 |  | ⬜ |
| `material_colour` |   | String | "#29B2B2" |  |  | 简单 |  | ⬜ |
| `material_density` |   | Float | 1.0 | 0~ |   | 简单 |  | ⬜ |
| `material_type` |   | String | "Tough" |  |  | 简单 |  | ⬜ |
| `material_vendor` |  | String | "" |  |  | 简单 |  | ⬜ |
| `metadata_name` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `metadata_value` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `min_save` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `mstpp` |  | Int | 300 |  |  | 简单 |  | ⬜ |
| `mtcpp` |  | Int | 1000000 |  |  | 简单 |  | ⬜ |
| `no_check` | No check | Bool | false |  |  | 简单 |  | ⬜ |
| `normative_check` |  | Bool | true |  |  | 简单 |  | ⬜ |
| `nozzle_flush_dataset` |  | Ints | 0 |  |  | 简单 |  | ⬜ |
| `nozzle_temperature` | Other layers | Ints | 200 | 0~ |  | 简单 |  | ⬜ |
| `nozzle_temperature_initial_layer` | Initial layer | Ints | 200 | 0~ |  | 简单 |  | ⬜ |
| `nozzle_temperature_range_high` | Max | Ints | 240 | 0~ |  | 简单 |  | ⬜ |
| `nozzle_temperature_range_low` | Min | Ints | 190 | 0~ |  | 简单 |  | ⬜ |
| `nozzle_volume_type` | Nozzle Volume Type | Enums | NozzleVolumeTy |  |  | 简单 |  | ⬜ |
| `orient` |  | Int | 0 |  |  | 简单 |  | ⬜ |
| `other_layers_print_sequence` | Other layers print seque | Ints | 0 | 0~16 |  | 简单 |  | ⬜ |
| `other_layers_print_sequence_nums` | The number of other laye | Int | 0 |  |  | 简单 |  | ⬜ |
| `output` | Output File | String |  |  |  | 简单 |  | ⬜ |
| `outputdir` |  | String |  |  |  | 简单 |  | ⬜ |
| `pad_around_object` |   | Bool | false |  |  | 简单 |  | ⬜ |
| `pad_around_object_everywhere` |   | Bool | false |  |  | 简单 |  | ⬜ |
| `pad_enable` |   | Bool | true |  |  | 简单 |  | ⬜ |
| `pad_wall_thickness` |   | Float | 2.0 | 0~30 |   | 简单 |  | ⬜ |
| `pipe` |  | String | "" |  |  | 简单 |  | ⬜ |
| `preset_name` |  | String |  |  |  | 简单 |  | ⬜ |
| `prime_tower_lift_height` |  | Float | -1 |  |  | 简单 |  | ⬜ |
| `prime_tower_width` | Width | Float | 35. | 2.0~ | mm | 简单 |  | ⬜ |
| `prime_volume` | Prime volume | Float | 45. | 1.0~ | mm³ | 简单 |  | ⬜ |
| `prime_volume_mode` |  | Enum | PrimeVolumeMod |  |  | 简单 |  | ⬜ |
| `print_compatible_printers` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `print_extruder_id` |  | Ints | 1 |  |  | 简单 |  | ⬜ |
| `print_extruder_variant` |  | Strings | "Direct Drive  |  |  | 简单 |  | ⬜ |
| `print_sequence` | Print sequence | Enum | PrintSequence: |  |  | 简单 |  | ⬜ |
| `print_settings_id` |  | String | "" |  |  | 简单 |  | ⬜ |
| `printable_height` | Printable height | Float | 100.0 | 0~1000 | mm | 简单 |  | ⬜ |
| `printer_extruder_id` |  | Ints | 1 |  |  | 简单 |  | ⬜ |
| `printer_extruder_variant` |  | Strings | "Direct Drive  |  |  | 简单 |  | ⬜ |
| `printer_model` | Printer type | String |  |  |  | 简单 |  | ✅ |
| `printer_settings_id` |  | String | "" |  |  | 简单 |  | ⬜ |
| `printer_technology` | Printer technology | Enum | ptFFF |  |  | 简单 |  | ⬜ |
| `printer_variant` | Printer variant | String |  |  |  | 简单 |  | ⬜ |
| `repair` | Repair | Bool | false |  |  | 简单 |  | ⬜ |
| `repetitions` |  | Int | 1 |  |  | 简单 |  | ⬜ |
| `rotate` |  | Float | 0 |  |  | 简单 |  | ⬜ |
| `rotate_x` |  | Float | 0 |  |  | 简单 |  | ⬜ |
| `rotate_y` |  | Float | 0 |  |  | 简单 |  | ⬜ |
| `scale` |  | Float | 1.f |  |  | 简单 |  | ⬜ |
| `single_instance` | Single instance mode | Bool |  |  |  | 简单 |  | ⬜ |
| `skip_modified_gcodes` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `skip_objects` |  | Ints |  |  |  | 简单 |  | ⬜ |
| `skip_useless_pick` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `sla_material_settings_id` |  | String | "" |  |  | 简单 |  | ⬜ |
| `sla_print_settings_id` |  | String | "" |  |  | 简单 |  | ⬜ |
| `slice` |  | Int | 0 |  |  | 简单 |  | ⬜ |
| `slow_down_layer_time` | Layer time | Ints | 5 | 0~1000 | s | 简单 | P4 | ⬜ |
| `spaghetti_detector` | Enable spaghetti detecto | Bool | false |  |  | 简单 |  | ⬜ |
| `spiral_mode` | Spiral vase | Bool | false |  |  | 简单 |  | ⬜ |
| `spiral_mode_smooth` | Smooth Spiral | Bool | false |  |  | 简单 |  | ⬜ |
| `split` | Split | Bool | Vec3d(0,0,0 |  |  | 简单 |  | ⬜ |
| `supertack_plate_temp` | Other layers | Ints | 35 | 0~120 |  | 简单 |  | ⬜ |
| `supertack_plate_temp_initial_layer` | Initial layer | Ints | 35 | 0~120 |  | 简单 |  | ⬜ |
| `supports_enable` |   | Bool | true |  |  | 简单 |  | ⬜ |
| `sw_renderer` | Render with a software r | Bool |  | 0~ |  | 简单 |  | ⬜ |
| `temperature_vitrification` | Softening temperature | Ints | 100 |  |  | 简单 |  | ⬜ |
| `textured_plate_temp` | Other layers | Ints | 45 | 0~120 |  | 简单 |  | ⬜ |
| `textured_plate_temp_initial_layer` | Initial layer | Ints | 45 | 0~120 |  | 简单 |  | ⬜ |
| `timelapse_type` | Timelapse | Enum | tlTraditional |  |  | 简单 |  | ⬜ |
| `uptodate` |  | Bool | false |  |  | 简单 |  | ⬜ |
| `uptodate_filaments` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `uptodate_settings` |  | Strings |  |  |  | 简单 |  | ⬜ |
| `volumetric_speed_coefficients` | Max volumetric speed mul | Strings | "" |  |  | 简单 |  | ⬜ |
| `absolute_correction` |   | Float | 0.0 |  |  | 高级 |  | ⬜ |
| `accel_to_decel_enable` | Enable accel_to_decel | Bool | false |  |  | 高级 |  | ⬜ |
| `accel_to_decel_factor` | accel_to_decel | Percent | 50 | 1~100 |  | 高级 |  | ⬜ |
| `ams_filament_load_time_ams` | AMS filament load time | Float | 0.0 | 0~ | s | 高级 |  | ⬜ |
| `ams_filament_load_time_ams_lite` | AMS Lite filament load t | Float | 0.0 | 0~ | s | 高级 |  | ⬜ |
| `ams_filament_load_time_n3f_s` | N3F/N3S filament load ti | Float | 0.0 | 0~ | s | 高级 |  | ⬜ |
| `ams_filament_unload_time_ams` | AMS filament unload time | Float | 0.0 | 0~ | s | 高级 |  | ⬜ |
| `ams_filament_unload_time_ams_lite` | AMS Lite filament unload | Float | 0.0 | 0~ | s | 高级 |  | ⬜ |
| `ams_filament_unload_time_n3f_s` | N3F/N3S filament unload  | Float | 0.0 | 0~ | s | 高级 |  | ⬜ |
| `apply_scarf_seam_on_circles` | Scarf Seam On Compensati | Bool | true |  |  | 高级 |  | ⬜ |
| `area_fill` |   | Float | 50. | 0~ |   | 高级 |  | ⬜ |
| `bed_custom_model` | Bed custom model | String | "" |  |  | 高级 |  | ⬜ |
| `bed_custom_texture` | Bed custom texture | String | "" |  |  | 高级 |  | ⬜ |
| `bed_exclude_area` | Bed exclude area | Points | Vec2d(0, 0 |  |  | 高级 |  | ⬜ |
| `best_object_pos` | Best object position | Point | Vec2d(0.5, 0.5 |  |  | 高级 |  | ⬜ |
| `change_filament_gcode` | Change filament G-code | String | "" |  |  | 高级 |  | ⬜ |
| `circle_compensation_manual_offset` | User Customized Offset | Float | 0.0 |  | mm | 高级 |  | ⬜ |
| `default_acceleration` | Normal printing | Floats | 500.0 | 0~ |  | 高级 |  | ⬜ |
| `default_ams_type` | Default AMS type | Int | -1 |  |  | 高级 |  | ⬜ |
| `default_filament_colour` | Default color | Strings | "" |  |  | 高级 |  | ⬜ |
| `default_jerk` | Default | Float | 0 | 0~ | mm/s | 高级 |  | ⬜ |
| `detect_floating_vertical_shell` | Detect floating vertical | Bool | true |  |  | 高级 |  | ⬜ |
| `display_mirror_x` |   | Bool | true |  |  | 高级 |  | ⬜ |
| `display_mirror_y` |   | Bool | false |  |  | 高级 |  | ⬜ |
| `display_orientation` |   | Enum | sladoPortrait |  |  | 高级 |  | ⬜ |
| `enable_arc_fitting` | Arc fitting | Bool | 0 |  |  | 高级 |  | ⬜ |
| `enable_circle_compensation` | Auto circle contour-hole | Bool | false |  |  | 高级 |  | ⬜ |
| `enable_wrapping_detection` | Enable clumping detectio | Bool | false |  |  | 高级 |  | ⬜ |
| `exclude_object` | Exclude objects | Bool | 1 |  |  | 高级 |  | ⬜ |
| `extruder_clearance_dist_to_rod` | Distance to rod | Float | 40 | 0~ | mm | 高级 |  | ⬜ |
| `extruder_clearance_height_to_lid` | Height to lid | Float | 120 | 0~ | mm | 高级 |  | ⬜ |
| `extruder_clearance_height_to_rod` | Height to rod | Float | 40 | 0~ | mm | 高级 |  | ⬜ |
| `extruder_clearance_max_radius` | Max Radius | Float | 68 | 0~ | mm | 高级 |  | ⬜ |
| `extruder_offset` | Extruder offset | Points | Vec2d(0,0 | -5~5 | mm | 高级 |  | ⬜ |
| `extruder_printable_area` | Extruder printable area | PointsGroups |  |  |  | 高级 |  | ⬜ |
| `extruder_printable_height` | Extruder printable heigh | Floats | 0 | 0~1000 | mm | 高级 |  | ⬜ |
| `extruder_type` | Type | Enums | ExtruderType:: |  |  | 高级 |  | ⬜ |
| `faded_layers` |   | Int | 10 | 3~20 |  | 高级 |  | ⬜ |
| `fast_tilt_time` |   | Float | 5. | 0~ |   | 高级 |  | ⬜ |
| `gamma_correction` |   | Float | 1.0 | 0~1 |  | 高级 |  | ⬜ |
| `hollowing_closing_distance` |   | Float | 2.0 | 0~10 | mm | 高级 |  | ⬜ |
| `hollowing_quality` |   | Float | 0.5 | 0~1 |  | 高级 |  | ⬜ |
| `host_type` | Host Type | Enum | htOctoPrint |  |  | 高级 |  | ⬜ |
| `infill_jerk` | Infill | Float | 9 | 0~ | mm/s | 高级 |  | ⬜ |
| `layer_change_gcode` | Layer change G-code | String | "" |  |  | 高级 |  | ⬜ |
| `long_retractions_when_ec` | Long retraction when ext | Bools | false |  |  | 高级 |  | ⬜ |
| `material_correction` |  | Floats | { 1., 1., 1. | 0~ |  | 高级 |  | ⬜ |
| `material_correction_x` |  | Float | 1. | 0~ |  | 高级 |  | ⬜ |
| `material_correction_y` |  | Float | 1. | 0~ |  | 高级 |  | ⬜ |
| `material_correction_z` |  | Float | 1. | 0~ |  | 高级 |  | ⬜ |
| `max_exposure_time` |   | Float | 100 | 0~ |   | 高级 |  | ⬜ |
| `max_initial_exposure_time` |   | Float | 150 | 0~ |   | 高级 |  | ⬜ |
| `max_layer_height` | Max | Floats | 0. | 0~ | mm | 高级 |  | ⬜ |
| `max_volumetric_extrusion_rate_slope_negative` | Max volumetric slope neg | Float | 0 | 0~ | mm³/s² | 高级 |  | ⬜ |
| `max_volumetric_extrusion_rate_slope_positive` | Max volumetric slope pos | Float | 0 | 0~ | mm³/s² | 高级 |  | ⬜ |
| `min_exposure_time` |   | Float | 0 | 0~ |   | 高级 |  | ⬜ |
| `min_initial_exposure_time` |   | Float | 0 | 0~ |   | 高级 |  | ⬜ |
| `min_layer_height` | Min | Floats | 0.07 | 0~ | mm | 高级 |  | ⬜ |
| `nozzle_diameter` | Nozzle diameter | Floats | 0.4 | ~1.0 | mm | 高级 |  | ✅ |
| `nozzle_volume` | Nozzle volume | Floats | {0.0 |  | mm³ | 高级 |  | ⬜ |
| `pad_brim_size` |   | Float | 1.6 | 0~30 |   | 高级 |  | ⬜ |
| `pad_max_merge_distance` |   | Float | 50.0 | 0~ |   | 高级 |  | ⬜ |
| `pad_object_connector_penetration` |   | Float | 0.3 | 0~ |   | 高级 |  | ⬜ |
| `pad_object_connector_stride` |   | Float | 10 | 0~ |   | 高级 |  | ⬜ |
| `pad_object_connector_width` |   | Float | 0.5 | 0~ |   | 高级 |  | ⬜ |
| `pad_object_gap` |   | Float | 1 | 0~10 |   | 高级 |  | ⬜ |
| `pad_wall_height` |   | Float | 0. | 0~30 |   | 高级 |  | ⬜ |
| `pad_wall_slope` |   | Float | 90.0 | 45~90 |   | 高级 |  | ⬜ |
| `post_process` | Post-processing Scripts | Strings |  |  |  | 高级 |  | ⬜ |
| `precise_z_height` | Precise Z height | Bool | 0 |  |  | 高级 |  | ⬜ |
| `preset_names` | Printer preset names | Strings |  |  |  | 高级 |  | ⬜ |
| `pressure_advance` | Pressure advance | Floats | 0.02 | ~2 |  | 高级 |  | ⬜ |
| `prime_tower_brim_width` | Brim width | Float | 3. | -1~ | mm | 高级 |  | ⬜ |
| `prime_tower_enable_framework` | Internal ribs | Bool | false |  |  | 高级 |  | ⬜ |
| `prime_tower_extra_rib_length` | Extra rib length | Float | 0 | ~300 | mm | 高级 |  | ⬜ |
| `prime_tower_fillet_wall` | Fillet wall | Bool | true |  |  | 高级 |  | ⬜ |
| `prime_tower_flat_ironing` |  | Bool | false |  |  | 高级 |  | ⬜ |
| `prime_tower_infill_gap` | Infill gap | Percent | 150 | 100~ | % | 高级 |  | ⬜ |
| `prime_tower_rib_wall` | Rib wall | Bool | true |  |  | 高级 |  | ⬜ |
| `prime_tower_rib_width` | Rib width | Float | 8 | 0~300 | mm | 高级 |  | ⬜ |
| `prime_tower_skip_points` | Skip points | Bool | true |  |  | 高级 |  | ⬜ |
| `print_host` | Hostname, IP or URL | String | "" |  |  | 高级 |  | ⬜ |
| `print_host_webui` | Device UI | String | "" |  |  | 高级 |  | ⬜ |
| `printable_area` | Printable area | Points | Vec2d(0, 0 |  |  | 高级 |  | ✅ |
| `printer_notes` | Printer notes | String | "" |  |  | 高级 |  | ⬜ |
| `printhost_apikey` | API Key / Password | String | "" |  |  | 高级 |  | ⬜ |
| `printhost_authorization_type` | Authorization Type | Enum | atKeyPassword |  |  | 高级 |  | ⬜ |
| `printhost_cafile` | HTTPS CA File | String | "" |  |  | 高级 |  | ⬜ |
| `printhost_password` | Password | String | "" |  |  | 高级 |  | ⬜ |
| `printhost_port` | Printer | String | "" |  |  | 高级 |  | ⬜ |
| `printhost_ssl_ignore_revoke` | Ignore HTTPS certificate | Bool | false |  |  | 高级 |  | ⬜ |
| `printhost_user` | User | String | "" |  |  | 高级 |  | ⬜ |
| `printing_by_object_gcode` | Between Object Gcode | String | "" |  |  | 高级 |  | ⬜ |
| `process_notes` | Process notes | String | "" |  |  | 高级 |  | ⬜ |
| `reduce_infill_retraction_mode` | Reduce infill retraction | Enum | rirAuto |  |  | 高级 |  | ⬜ |
| `relative_correction` |   | Floats | { 1., 1. | 0~ |  | 高级 |  | ⬜ |
| `relative_correction_x` |   | Float | 1. | 0~ |  | 高级 |  | ⬜ |
| `relative_correction_y` |   | Float | 1. | 0~ |  | 高级 |  | ⬜ |
| `relative_correction_z` |   | Float | 1. | 0~ |  | 高级 |  | ⬜ |
| `resolution` | Resolution | Float | 0.01 | 0~ | mm | 高级 |  | ⬜ |
| `retract_before_wipe` | Retract amount before wi | Percents | 100 |  |  | 高级 |  | ⬜ |
| `retract_lift_above` | Z hop lower boundary | Floats | 0. | 0~ | mm | 高级 |  | ⬜ |
| `retract_lift_below` | Z hop upper boundary | Floats | 0. | 0~ | mm | 高级 |  | ⬜ |
| `retract_when_changing_layer` | Retract when change laye | Bools | false |  |  | 高级 |  | ⬜ |
| `slow_tilt_time` |   | Float | 8. | 0~ |   | 高级 |  | ⬜ |
| `spiral_mode_max_xy_smoothing` | Max XY Smoothing | FloatOrPercent | 200, true | 0~1000 | mm or % | 高级 |  | ⬜ |
| `template_custom_gcode` | Custom G-code | String | "" |  |  | 高级 |  | ⬜ |
| `time_lapse_gcode` | Time lapse G-code | String | "" |  |  | 高级 |  | ⬜ |
| `travel_acceleration` | Travel | Floats | 500.0 | 0~ |  | 高级 |  | ⬜ |
| `travel_jerk` | Travel | Float | 9 | 0~ | mm/s | 高级 |  | ⬜ |
| `use_firmware_retraction` | Use firmware retraction | Bool | false |  |  | 高级 |  | ⬜ |
| `use_relative_e_distances` | Use relative E distances | Bool | true |  |  | 高级 |  | ✅ |
| `wrapping_detection_gcode` | Clumping detection G-cod | String | "" |  |  | 高级 |  | ⬜ |
| `wrapping_exclude_area` | Probing exclude area of  | Points |  |  |  | 高级 |  | ⬜ |
| `bed_temperature_formula` | Bed temperature type | Enum | BedTempFormula |  |  | 开发 |  | ⬜ |
| `before_layer_change_gcode` | Before layer change G-co | String | "" |  |  | 开发 |  | ⬜ |
| `compatible_printers` | Compatible machine | Strings |  |  |  | 开发 |  | ⬜ |
| `compatible_printers_condition` | Compatible machine condi | String |  |  |  | 开发 |  | ⬜ |
| `compatible_prints` | Compatible process profi | Strings |  |  |  | 开发 |  | ⬜ |
| `compatible_prints_condition` | Compatible process profi | String |  |  |  | 开发 |  | ⬜ |
| `default_nozzle_volume_type` | Default Nozzle Volume Ty | Enums | NozzleVolumeTy |  |  | 开发 |  | ⬜ |
| `draft_shield` | Draft shield | Enum | dsDisabled |  |  | 开发 |  | ⬜ |
| `enable_long_retraction_when_cut` |  | Int | 0 |  |  | 开发 |  | ⬜ |
| `enable_order_independent_overlap_carving` | Order-independent overla | Bool | false |  |  | 开发 |  | ⬜ |
| `enable_tower_interface_features` | Enable tower interface f | Bool | false |  |  | 开发 |  | ⬜ |
| `extruder_colour` | Extruder Color | Strings | "" |  |  | 开发 |  | ⬜ |
| `extruder_max_nozzle_count` |  | Ints | 1 |  |  | 开发 |  | ⬜ |
| `extruder_nozzle_count` |  | Ints | 1 |  |  | 开发 |  | ⬜ |
| `extruder_nozzle_volume_type` |  | Enums | NozzleVolumeTy |  |  | 开发 |  | ⬜ |
| `filename_format` | Filename format | String | "[input_filena |  |  | 开发 |  | ⬜ |
| `filter_out_gap_fill` | Filter out tiny gaps | Float | 0 |  | mm | 开发 |  | ⬜ |
| `grab_length` | Grab length | Floats | {0 | 0~ | mm | 开发 |  | ⬜ |
| `head_wrap_detect_zone` |  | Points |  |  |  | 开发 |  | ⬜ |
| `impact_strength_z` | Impact Strength Z | Floats | 0 |  |  | 开发 |  | ⬜ |
| `long_retractions_when_cut` | Long retraction when cut | Bools | false |  |  | 开发 |  | ⬜ |
| `nozzle_height` | Nozzle height | Float | 4 | 0~ | mm | 开发 |  | ⬜ |
| `ooze_prevention` | Enable | Bool | false |  |  | 开发 |  | ⬜ |
| `physical_extruder_map` |  | Ints | 0 |  |  | 开发 |  | ⬜ |
| `preset_names` | Printer preset names | Strings |  |  |  | 开发 |  | ⬜ |
| `print_in_clockwise` | Print loops in clockwise | Bool | false |  |  | 开发 |  | ⬜ |
| `printer_structure` | Printer structure | Enum | psUndefine |  |  | 开发 |  | ⬜ |
| `retract_length_toolchange` | Length | Floats | 10. |  | mm | 开发 |  | ⬜ |
| `retract_restart_extra` | Extra length on restart | Floats | 0. |  | mm | 开发 |  | ⬜ |
| `retract_restart_extra_toolchange` | Extra length on restart | Floats | 0. |  | mm | 开发 |  | ⬜ |
| `scan_first_layer` | Scan first layer | Bool | false |  |  | 开发 |  | ⬜ |
| `silent_mode` | Supports silent mode | Bool | false |  |  | 开发 |  | ✅ |
| `single_extruder_multi_material` | Single Extruder Multi Ma | Bool | false |  |  | 开发 |  | ⬜ |
| `standby_temperature_delta` | Temperature variation | Int | -5 |  |  | 开发 |  | ⬜ |
| `start_end_points` | Start end points | Points | Vec2d(30, -3 |  |  | 开发 |  | ⬜ |
| `thumbnail_size` | Thumbnail size | Points | Vec2d(50,50 |  |  | 开发 |  | ⬜ |
| `top_area_threshold` | Top area threshold | Percent | 200 | 0~500 |  | 开发 |  | ⬜ |
| `travel_short_distance_acceleration` | Short travel | Floats | 250 | 0~ |  | 开发 |  | ⬜ |
| `travel_speed_z` | Z travel | Floats | 0. | 0~ | mm/s | 开发 |  | ⬜ |
| `upward_compatible_machine` | upward compatible machin | Strings |  |  |  | 开发 |  | ⬜ |
| `wrapping_detection_layers` | Clumping detection layer | Int | 20 | 0~ |  | 开发 |  | ⬜ |