load("//ng_package/rollup:utils.bzl", 
  "WELL_KNOWN_EXTERNALS",
  "serialize_file",
  "find_matching_file",
  "filter_esm_files_to_include",
  "serialize_files_for_arg"
)
load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("//ng_project/config:compilation_mode.bzl", "partial_compilation_transition")
load("//ng_package/bundle_types:index.bzl", "bundle_type_declaration")



def _ng_package_rollup_impl(ctx):
  npm_package_directory = ctx.actions.declare_directory("%s.ng_pkg" % ctx.label.name)
  
  rollup_config = _write_rollup_config(ctx)

  args = ctx.actions.args()
  args.add("--config", rollup_config.short_path)

  inputs = depset([rollup_config])

  outputs = [npm_package_directory]
  ctx.actions.run(
      inputs = inputs,
      outputs = outputs,
      executable = ctx.executable._rollup_bin,
      tools = [ctx.executable._rollup_bin],
      arguments = [args],
      env = {
        "BAZEL_BINDIR": ctx.bin_dir.path,
      },
  )

  return [
    DefaultInfo(files = depset(outputs))
  ]



ng_package_rollup = rule(
  implementation = _ng_package_rollup_impl,
  attrs = {    
    "side_effect_entry_points": attr.string_list(
        doc = "List of entry-points that have top-level side-effects",
        default = [],
    ),
    "deps": attr.label_list(
        doc = """ Targets that produce production JavaScript outputs, such as `ts_library`.""",
        cfg = partial_compilation_transition,
    ),
    "srcs": attr.label_list(
        doc = """JavaScript source files from the workspace.
        These can use ES2022 syntax and ES Modules (import/export)""",
        cfg = partial_compilation_transition,
        allow_files = True,
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
    "readme_md": attr.label(allow_single_file = [".md"]),
    "license": attr.label(
        doc = """A textfile that will be copied to the root of the npm package.""",
        allow_single_file = True,
    ),

    "skip_type_bundling": attr.string_list(
        default = [],
        doc = """
          List of entry-points for which type bundle generation should be skipped. Requires a
          self-contained `index.d.ts` to be generated (i.e. with no relative imports).

          Skipping of bundling might be desirable due to limitations in Microsoft's API extractor.
          For example when `declare global` is used: https://github.com/microsoft/rushstack/issues/2090.

          ```
              "",                # Skips the primary entry-point from bundling.
              "testing",         # Skips the testing entry-point from type bundling
              "select/testing",  # Skips the `select/testing` entry-point
          ```
        """,
    ),

    "_rollup_config_tmpl": attr.label(
        default = Label("//ng_package/rollup:rollup.config.js"),
        allow_single_file = True,
    ),

    
    "_rollup_bin": attr.label(
        default = Label("//ng_package/rollup:rollup"),
        cfg = "exec",
        executable = True,
    ),

    # Needed in order to allow for the outgoing transition on the `deps` attribute.
    # https://docs.bazel.build/versions/main/skylark/config.html#user-defined-transitions.
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
  },
)



def _write_rollup_config(ctx):
  config = ctx.actions.declare_file("_%s.rollup.conf.js" % ctx.label.name)
  metadata_arg = {}
  mappings = {}
  externals = WELL_KNOWN_EXTERNALS

  # Pass external & globals through a templated config file because on Windows there is
  # an argument limit and we there might be a lot of globals which need to be passed to
  # rollup.

  ctx.actions.expand_template(
      output = config,
      template = ctx.file._rollup_config_tmpl,
      substitutions = {
          "TMPL_banner_file": "\"%s\"" % ctx.file.license_banner.path if ctx.file.license_banner else "undefined",
          "TMPL_module_mappings": str(mappings),
          # TODO: Figure out node_modules root
          "TMPL_node_modules_root": "node_modules",
          "TMPL_metadata": json.encode(metadata_arg),
          "TMPL_root_dir": ctx.bin_dir.path,
          "TMPL_workspace_name": ctx.workspace_name,
          "TMPL_external": ", ".join(["'%s'" % e for e in externals]),
          "TMPL_side_effect_entrypoints": json.encode(ctx.attr.side_effect_entry_points),
      },
  )
  
  return config

