"""Module extension for defining needed dependencies from root module."""

load("@aspect_rules_js//npm:repositories.bzl", "npm_translate_lock")

angular = module_extension(
    implementation = _deps_impl,
    tag_classes = {
        "deps": tag_class(attrs = _angular_deps_attrs()),
    },
)

_BUILD_TEMPLATE = """
alias(
    name = "angular_compiler_cli",
    actual = "{angular_compiler_cli}",
    visibility = ["//visibility:public"],
)

alias(
    name = "typescript",
    actual = "{typescript}",
    visibility = ["//visibility:public"],
)
"""

_expose_deps = repository_rule(
    implementation = _expose_deps_impl,
    attrs = _angular_deps_attrs(),
)

def _expose_deps_impl(ctx):
    ctx.file(
        "BUILD.bazel",
        _BUILD_TEMPLATE.format(
            angular_compiler_cli = rctx.attr.angular_compiler_cli,
            typescript = rctx.attr.typescript,
        ),
    )

def _deps_impl(unused_module_ctx):
    npm_translate_lock(
        name = "rules_angular_npm",
        npmrc = "//:.npmrc",
        data = [
            "@rules_angular//:package.json",
        ],
        pnpm_lock = "@rules_angular//:pnpm-lock.yaml",
    )

    load("@rules_angular_npm//:repositories.bzl", "npm_repositories")

    npm_repositories()

    _expose_deps(
        name = "rules_angular_configurable_deps",
        angular_compiler_cli = rctx.attr.angular_compiler_cli,
        typescript = rctx.attr.typescript,
    )

def _angular_deps_attrs():
    attrs = dict()

    # Add macro attrs that aren't in the rule attrs.
    attrs["angular_compiler_cli"] = attr.label(
        mandatory = True,
        doc = "Label pointing to the `@angular/compiler-cli` package.",
    )
    attrs["typescript"] = attr.label(
        mandatory = True,
        doc = "Label pointing to the `typescript` package.",
    )
    return attrs
