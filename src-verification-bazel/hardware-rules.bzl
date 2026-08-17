"""
Bazel rule transpiling Verilator to C++.
"""

def _verilator_transpile_impl(ctx):
    top_module = ctx.attr.top_module

    all_srcs = ctx.files.srcs + ctx.files.deps

    out_dir = ctx.actions.declare_directory(ctx.label.name + "_obj_dir")

    verilator = ctx.executable._verilator

    args = ctx.actions.args()
    args.add("--cc")  # emit C++ output
    args.add("--top-module", top_module)
    args.add("-Mdir", out_dir.path)

    args.add_all(ctx.attr.verilator_flags)

    # Add include dirs, if any were passed
    for inc in ctx.attr.includes:
        args.add("-I" + inc)

    # Finally, add all the source files
    args.add_all(all_srcs)

    ctx.actions.run(
        executable = verilator,
        arguments = [args],
        inputs = all_srcs,
        outputs = [out_dir],
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
        "_verilator": attr.label(
            default = Label("//src-verification-bazel/tools:verilator"),
            executable = True,
            cfg = "exec",
        ),
    },
)