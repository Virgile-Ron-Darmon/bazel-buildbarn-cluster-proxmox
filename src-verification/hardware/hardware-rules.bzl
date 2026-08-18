"""
Bazel rule transpiling Verilator to C++.
"""
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("@rules_foreign_cc//foreign_cc:defs.bzl", "make")

def _verilator_transpile_impl(ctx):
    top_module = ctx.attr.top_module

    all_srcs = ctx.files.srcs + ctx.files.deps

    verilator_cpp = None
    cocotb_libs_dir = None
    for f in ctx.files._cocotb_whl:
        if f.path.endswith("cocotb/share/lib/verilator/verilator.cpp"):
            verilator_cpp = f
        if f.path.endswith("cocotb/libs/libcocotbvpi_verilator.so"):
            cocotb_libs_dir = f.dirname   # the whole cocotb/libs directory
    if verilator_cpp == None:
        fail("verilator.cpp not found in cocotb wheel")
    if cocotb_libs_dir == None:
        fail("cocotb libs dir not found in wheel")

    cocotb_lib_files = [
        f for f in ctx.files._cocotb_whl
        if "/cocotb/libs/" in f.path and f.path.endswith(".so")
    ]

    out_dir = ctx.actions.declare_directory(ctx.label.name + "_obj_dir")

    verilator = ctx.executable._verilator

    args = ctx.actions.args()
    args.add("--cc")  # emit C++ output
    args.add("--exe")  # creates executable
    args.add("--vpi") # cocotb's shim needs Verilog Procedural Interface
    args.add("--prefix", "Vtop")  # cocotb's shim expects the class/header to be literally "Vtop"
    args.add("--top-module", top_module)
    args.add("-Mdir", out_dir.path)

    args.add_all(ctx.attr.verilator_flags)

    for inc in ctx.attr.includes:
        args.add("-I" + inc)

    # Add the regular source files
    args.add_all(all_srcs)

    # Add the (not-yet-existing) copied verilator.cpp path, inside out_dir.
    # This is what actually gets embedded into the generated Vrisc_v.mk.
    args.add("verilator.cpp")

    ctx.actions.run_shell(
        inputs = all_srcs + [verilator_cpp] + cocotb_lib_files,
        outputs = [out_dir],
        tools = [verilator],
        command = """
set -euo pipefail
mkdir -p "{out_dir}"
cp "{verilator_cpp}" "{out_dir}/verilator.cpp"
cp {cocotb_libs} "{out_dir}/"
"{verilator}" "$@"
""".format(
            out_dir = out_dir.path,
            verilator_cpp = verilator_cpp.path,
            cocotb_libs = " ".join([f.path for f in cocotb_lib_files]),
            verilator = verilator.path,
        ),
        arguments = [args],
        mnemonic = "VerilatorCompile",
        progress_message = "Running Verilator on %s (top=%s)" % (ctx.label, top_module),
    )

    return [DefaultInfo(files = depset([out_dir]))]

verilator_transpile = rule(
    implementation = _verilator_transpile_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".sv", ".v"],
            mandatory = True,
            doc = "Top-level SystemVerilog source file(s).",
        ),
        "deps": attr.label_list(
            allow_files = [".sv", ".v", ".svh", ".vh"],
            default = [],
            doc = "SystemVerilog/Verilog files instantiated by srcs (submodules, headers).",
        ),
        "top_module": attr.string(
            mandatory = True,
            doc = "Name of the top-level module for Verilator elaboration.",
        ),
        "includes": attr.string_list(
            default = [],
            doc = "Include directories passed to Verilator via -I.",
        ),
        "verilator_flags": attr.string_list(
            default = [],
            doc = "Extra flags passed straight through to Verilator (e.g. --trace, -Wall).",
        ),
        "_cocotb_whl": attr.label(
            default = Label("@pypi//cocotb:extracted_whl_files"),
            allow_files = True,
        ),
        "_verilator": attr.label(
            default = Label("//third_party/verilator:verilator"),
            executable = True,
            cfg = "exec",
        ),
    },
)


def cocotb_module_test(name, top_module, srcs, test_src, test_module, deps = [], verilator_flags = []):
    verilator_transpile(
        name = name + "_verilated",
        srcs = srcs,
        deps = deps,
        top_module = top_module,
        verilator_flags = verilator_flags,
    )

    native.filegroup(
        name = name + "_obj_dir_files",
        srcs = [":" + name + "_verilated"],
    )

    make(
        name = name + "_bin",
        lib_source = ":" + name + "_obj_dir_files",
        deps = ["//third_party/verilator:verilator_build"],
        env = {"CCACHE_DISABLE": "1"},
        targets = [
            "-C " + name + "_verilated_obj_dir -f Vtop.mk VERILATOR_ROOT=$$EXT_BUILD_DEPS$$/verilator_build/share/verilator LDFLAGS=-Wl,-rpath,\\$$ORIGIN LDLIBS=-L.\\ -l:libcocotbvpi_verilator.so\\ -l:libgpi.so\\ -l:libgpilog.so",
        ],
        postfix_script = "mkdir -p $$INSTALLDIR/bin && cp " + name + "_verilated_obj_dir/Vtop $$INSTALLDIR/bin/Vtop",
        out_binaries = ["Vtop"],
    )

    sh_test(
        name = name,
        srcs = ["//src-verification/hardware:cocotb_test.sh"],
        args = [
            "_main/%s/%s_bin/bin/Vtop" % (native.package_name(), name),
            "_main/%s/%s_verilated_obj_dir" % (native.package_name(), name),
            "$(rlocationpath @python_3_12//:python3)",
            native.package_name(),
            test_module,
            top_module,
        ],
        data = [
            ":" + name + "_bin",
            ":" + name + "_verilated",
            test_src,
            "@pypi//cocotb:extracted_whl_files",
            "@python_3_12//:python3",
            "@python_3_12//:files",
        ],
    )