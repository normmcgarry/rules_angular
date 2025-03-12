load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("//ng_project/config:compilation_mode.bzl", "partial_compilation_transition")



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
    "srcs": attr.label_list(
        doc = """JavaScript source files from the workspace.
        These can use ES2022 syntax and ES Modules (import/export)""",
        cfg = partial_compilation_transition,
        allow_files = True,
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
  externals = []

  # Pass external & globals through a templated config file because on Windows there is
  # an argument limit and we there might be a lot of globals which need to be passed to
  # rollup.

  ctx.actions.expand_template(
      output = config,
      template = ctx.file._rollup_config_tmpl,
      substitutions = {
          "TMPL_banner_file": "undefined",
          "TMPL_module_mappings": str(mappings),
          # TODO: Figure out node_modules root
          "TMPL_node_modules_root": "node_modules",
          "TMPL_metadata": json.encode(metadata_arg),
          "TMPL_root_dir": ctx.bin_dir.path,
          "TMPL_workspace_name": ctx.workspace_name,
          "TMPL_external": ", ".join(["'%s'" % e for e in externals]),
          "TMPL_side_effect_entrypoints": json.encode([]),
      },
  )
  
  return config

