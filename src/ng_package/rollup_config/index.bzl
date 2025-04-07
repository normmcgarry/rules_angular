load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("//src/ng_project/config:compilation_mode.bzl", "partial_compilation_transition")

# Prints a debug message if "--define=VERBOSE_LOGS=true" is specified.
def _debug(vars, *args):
    if "VERBOSE_LOGS" in vars.keys():
        print("[ng_package.bzl]", args)


_DEFAULT_ROLLUP_CONFIG_TMPL = "//src/ng_package/rollup_config:rollup.config.js"

_NG_PACKAGE_MODULE_MAPPINGS_ATTR = "ng_package_module_mappings"

WELL_KNOWN_EXTERNALS = [
    "@angular/animations",
    "@angular/animations/browser",
    "@angular/animations/browser/testing",
    "@angular/common",
    "@angular/common/http",
    "@angular/common/http/testing",
    "@angular/common/testing",
    "@angular/common/upgrade",
    "@angular/compiler",
    "@angular/core",
    "@angular/core/testing",
    "@angular/elements",
    "@angular/forms",
    "@angular/localize",
    "@angular/localize/init",
    "@angular/platform-browser",
    "@angular/platform-browser/animations",
    "@angular/platform-browser/testing",
    "@angular/platform-browser-dynamic",
    "@angular/platform-browser-dynamic/testing",
    "@angular/platform-server",
    "@angular/platform-server/init",
    "@angular/platform-server/testing",
    "@angular/router",
    "@angular/router/testing",
    "@angular/router/upgrade",
    "@angular/service-worker",
    "@angular/service-worker/config",
    "@angular/upgrade",
    "@angular/upgrade/static",
    "rxjs",
    "rxjs/operators",
    "tslib",
]

def find_entry_point_js(dep):
    for file in dep[JsInfo].sources.to_list():
        if file.basename == 'index.js':
            return file
    return None

def find_entry_point_dts(dep):
    for file in dep[JsInfo].types.to_list():
        if file.basename == 'index.d.ts':
            return file
    return None

def join(*list):
    return "/".join([item for item in list if len(item) > 0])
    


def _ng_package_rollup_config_impl(ctx):
    filename = "_%s_%s.rollup.conf.js" % (ctx.label.name, ctx.attr.mode)
    config = ctx.actions.declare_file(filename)
    mappings = {}
    

    externals = WELL_KNOWN_EXTERNALS + ctx.attr.externals

    metadata_arg = {}

    for dep in ctx.attr.srcs:
        if not JsInfo in dep:
            continue

        package_name = ctx.attr.package
        base_path = ctx.label.package

        entry_point_js = find_entry_point_js(dep)
        entry_point_dts = find_entry_point_dts(dep)

        
        entry_point_js_pkg_relative = entry_point_js.short_path[len(base_path)+1:][:-(len(entry_point_js.basename)+1)]
        entry_point_dts_pkg_relative = entry_point_dts.short_path[len(base_path)+1:][:-(len(entry_point_dts.basename)+1)]
        metadata_arg[join(package_name, entry_point_js_pkg_relative)] = {
            "dtsBundleRelativePath": join(entry_point_dts_pkg_relative, "index.d.ts"),
            "fesm2022RelativePath": join("fesm2022" , "%s.mjs" % (entry_point_js_pkg_relative if entry_point_js_pkg_relative else package_name.split("/")[-1])),
            "index": {
                "path": entry_point_js.path,
                "short_path": entry_point_js.short_path
            },
            "typingsEntryPoint": {
                "path": entry_point_dts.path,
                "short_path": entry_point_dts.short_path
            },
        }

    # Pass external & globals through a templated config file because on Windows there is
    # an argument limit and we there might be a lot of globals which need to be passed to
    # rollup.
    ctx.actions.expand_template(
        output = config,
        template = ctx.file.rollup_config_tmpl,
        substitutions = {
            "TMPL_banner_file": "\"%s\"" % ctx.file.license_banner.path if ctx.file.license_banner else "undefined",
            "TMPL_module_mappings": str(mappings),
            "TMPL_metadata": json.encode(metadata_arg),
            "TMPL_root_dir": ctx.bin_dir.path,
            "TMPL_workspace_name": ctx.workspace_name,
            "TMPL_external": ", ".join(["'%s'" % e for e in externals]),
            "TMPL_side_effect_entrypoints": json.encode(ctx.attr.side_effect_entry_points),
            "TMPL_dts_mode": "true" if ctx.attr.mode == "dts" else "false",
        },
    )

    return [
        DefaultInfo(files = depset([config])),
    ]

ng_package_rollup_config = rule(
    implementation = _ng_package_rollup_config_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "TODO",
            allow_files = True,
            cfg = partial_compilation_transition,
        ),
        "package": attr.string(
            doc = "TODO",
            mandatory = True,
        ),
        "mode": attr.string(
            doc = "TODO",
            mandatory = True,
            values = ["dts", "fesm"],
        ),
        "side_effect_entry_points": attr.string_list(
            doc = "List of entry-points that have top-level side-effects",
            default = [],
        ),
        "externals": attr.string_list(
            doc = """List of external module that should not be bundled into the flat ESM bundles.""",
            default = [],
        ),
        "license_banner": attr.label(
            doc = """A .txt file passed to the `banner` config option of rollup.
        The contents of the file will be copied to the top of the resulting bundles.
        Configured substitutions are applied like with other files in the package.""",
            allow_single_file = [".txt"],
        ),
        "rollup_config_tmpl": attr.label(
            default = Label(_DEFAULT_ROLLUP_CONFIG_TMPL),
            allow_single_file = True,
        ),
        # Needed in order to allow for the outgoing transition on the `deps` attribute.
        # https://docs.bazel.build/versions/main/skylark/config.html#user-defined-transitions.
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
