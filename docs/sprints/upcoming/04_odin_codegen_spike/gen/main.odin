// Throwaway spike for 04_odin_codegen.md: prints GLSL-ish structs for tagged declarations.
// Run from the spike directory with an absolute input path. A relative path fails to parse
// under the agent sandbox, where filepath.abs returns Permission_Denied (checked 2026-11-25):
//   odin run gen -- "$PWD/input"
package gen

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"

main :: proc() {
	pkg, ok := parser.parse_package_from_path(os.args[1])
	if !ok {
		fmt.eprintfln("failed to parse package %q", os.args[1])
		os.exit(1)
	}
	for _, file in pkg.files {
		for stmt in file.decls {
			decl := stmt.derived.(^ast.Value_Decl) or_continue
			tag := attribute(decl)
			if tag == "" || len(decl.values) != 1 do continue
			st := decl.values[0].derived.(^ast.Struct_Type) or_continue
			name := decl.names[0].derived.(^ast.Ident).name
			fmt.printfln("// tag=%s", tag)
			fmt.printfln("struct %s {{", name)
			for field in st.fields.list {
				for n in field.names {
					fmt.printfln("    %s %s;", glsl_type(field.type), n.derived.(^ast.Ident).name)
				}
			}
			fmt.println("};")
		}
	}
}

attribute :: proc(decl: ^ast.Value_Decl) -> string {
	for attr in decl.attributes {
		for elem in attr.elems {
			#partial switch e in elem.derived {
			case ^ast.Ident:       return e.name
			case ^ast.Field_Value: return e.field.derived.(^ast.Ident).name
			}
		}
	}
	return ""
}

glsl_type :: proc(expr: ^ast.Expr) -> string {
	#partial switch t in expr.derived {
	case ^ast.Ident:
		switch t.name {
		case "f32": return "float"
		case "u64": return "uint64_t"
		}
		return fmt.tprintf("/* unresolved alias %s */", t.name)
	case ^ast.Array_Type:
		elem := t.elem.derived.(^ast.Ident).name
		n := t.len.derived.(^ast.Basic_Lit).tok.text
		if elem == "f32" do return fmt.tprintf("vec%s", n)
	}
	return "/* ? */"
}
