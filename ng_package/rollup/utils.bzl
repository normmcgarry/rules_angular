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

# Serializes a file into a struct that matches the `BazelFileInfo` type in the
# packager implementation. Useful for transmission of such information.
def serialize_file(file):
    return struct(path = file.path, shortPath = file.short_path)


# Serializes a list of files into a JSON string that can be passed as CLI argument
# for the packager, matching the `BazelFileInfo[]` type in the packager implementation.
def serialize_files_for_arg(files):
    result = []
    for file in files:
        result.append(serialize_file(file))
    return json.encode(result)


def find_matching_file(files, search_short_paths):
    print("####################")
    print(files)
    print(search_short_paths)
    print("####################")
    for file in files:
        for search_short_path in search_short_paths:
            if file.short_path == search_short_path:
                return file
    fail("Could not find file that matches: %s" % (", ".join(search_short_paths)))



def filter_esm_files_to_include(files, owning_package):
    result = []

    for file in files:
        # We skip all `.externs.js` files as those should not be shipped as part of
        # the ESM2022 output. The externs are empty because `ngc-wrapped` disables
        # externs generation in prodmode for workspaces other than `google3`.
        if file.path.endswith("externs.js"):
            continue

        # We omit all non-JavaScript files. These are not required for the FESM bundle
        # generation and are not expected to be put into the `esm2022` output.
        if not file.path.endswith(".js") and not file.path.endswith(".mjs"):
            continue

        if file.short_path.startswith(owning_package):
            result.append(file)

    return result