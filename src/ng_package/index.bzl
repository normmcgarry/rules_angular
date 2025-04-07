load("@aspect_rules_js//npm:defs.bzl", _npm_package = "npm_package")
load("//src/ng_package:angular_package_format.bzl", "angular_package_format")
load("//src/ng_package/rollup_config:index.bzl", "ng_package_rollup_config")
load("//src/ng_package/rollup:index.bzl", "ng_package_rollup")


def ng_package(
    name,
    deps = [],
    srcs = [],
    externals = [],
    license_banner = None,
    package = None,
    side_effect_entry_points = []):

    ng_package_rollup_config(
        name = "%s_fesm_config" % name,
        mode = "fesm",
        srcs = srcs,
        package = package,
        externals = externals,
        license_banner = license_banner,
        side_effect_entry_points = side_effect_entry_points
    )

    ng_package_rollup_config(
        name = "%s_dts_config" % name,
        mode = "dts",
        srcs = srcs,
        package = package,
        externals = externals,
        license_banner = license_banner,
        side_effect_entry_points = side_effect_entry_points
    )

    ng_package_rollup(
        name = "%s_fesm_bundle" % name,
        srcs = srcs,
        config = ":%s_fesm_config" % name,
        mode = "fesm",
        deps = [
            "//:node_modules/@rollup/plugin-commonjs",
            "//:node_modules/@rollup/plugin-node-resolve",
            "//:node_modules/magic-string",
            "//:node_modules/rollup-plugin-dts",
            "//:node_modules/rollup-plugin-sourcemaps2",
        ],
    )

    ng_package_rollup(
        name = "%s_dts_bundle" % name,
        srcs = srcs,
        config = ":%s_dts_config" % name,
        mode = "dts",
        deps = [
            "//:node_modules/@rollup/plugin-commonjs",
            "//:node_modules/@rollup/plugin-node-resolve",
            "//:node_modules/magic-string",
            "//:node_modules/rollup-plugin-dts",
            "//:node_modules/rollup-plugin-sourcemaps2",
        ],
    )

