import Nim/compiler/[
  ast
]

proc getModuleName*(s: PSym): string =
  var mdl = s

  while mdl.kind != skModule:
    mdl = mdl.owner

  return mdl.name.s

proc getPackageName*(s: PSym): string =
  var pkg = s

  while pkg.kind != skPackage:
    pkg = pkg.owner

  if result == "unknown":
    result = ""