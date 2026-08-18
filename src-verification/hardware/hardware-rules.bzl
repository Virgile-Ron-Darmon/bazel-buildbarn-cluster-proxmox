"""
Bazel rule transpiling Verilator to C++.
"""

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