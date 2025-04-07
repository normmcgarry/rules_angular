load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("//src/ng_project/config:compilation_mode.bzl", "partial_compilation_transition")

# Prints a debug message if "--define=VERBOSE_LOGS=true" is specified.
def _debug(vars, *args):
    if "VERBOSE_LOGS" in vars.keys():
        print("[ng_package.bzl]", args)


_DEFAULT_ROLLUP = "//src/ng_package/rollup:bin"

def _ng_package_rollup_impl(ctx):
    bundles_directory = ctx.actions.declare_directory("%s.%s_bundles" % (ctx.label.name, ctx.attr.mode))

    args = ctx.actions.args()
    args.add("--config", ctx.file.config)
    args.add("--output.format", "esm")
    args.add("--output.dir", bundles_directory.path)
    args.add("--preserveSymlinks")

    # We will produce errors as needed. Anything else is spammy: a well-behaved
    # bazel rule prints nothing on success.
    args.add("--silent")

    inputs = depset(ctx.files.deps)
    other_inputs = [ctx.file.config] + ctx.files.srcs
    ctx.actions.run(
        progress_message = "ng_package: Rollup %s (%s)" % (ctx.label, ctx.attr.mode),
        mnemonic = "NgPackageRollup",
        inputs = depset(other_inputs, transitive = [inputs]),
        outputs = [bundles_directory],
        executable = ctx.executable._rollup,
        arguments = [args],
        env = {
            "BAZEL_BINDIR": ".",
        },
    )

    return [
        DefaultInfo(files = depset([bundles_directory])),
    ]

ng_package_rollup = rule(
    implementation = _ng_package_rollup_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "TODO",
            allow_files = True,
            cfg = partial_compilation_transition,
        ),
        "deps": attr.label_list(
            doc = "TODO",
            allow_files = True,
        ),
        "mode": attr.string(
            doc = "TODO",
            mandatory = True,
            values = ["dts", "fesm"],
        ),
        "_rollup": attr.label(
            default = Label(_DEFAULT_ROLLUP),
            executable = True,
            cfg = "exec",
        ),
        "config": attr.label(
            mandatory = True,
            doc = "TODO",
            allow_single_file = True,
        ),
        "_rollup_runtime_deps": attr.label_list(
            default = [
                Label("//:node_modules/@rollup/plugin-commonjs"),
                Label("//:node_modules/@rollup/plugin-node-resolve"),
                Label("//:node_modules/magic-string"),
                Label("//:node_modules/rollup-plugin-dts"),
                Label("//:node_modules/rollup-plugin-sourcemaps2"),
            ],
        ),

        # Needed in order to allow for the outgoing transition on the `deps` attribute.
        # https://docs.bazel.build/versions/main/skylark/config.html#user-defined-transitions.
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
