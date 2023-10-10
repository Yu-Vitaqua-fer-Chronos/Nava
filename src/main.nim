import std/[
  tables,
  sets,
  os
]

import Nim/compiler/[
  modulegraphs,
  pathutils,
  lineinfos,
  condsyms,
  passaux,
  modules,
  astalgo,
  options,
  passes,
  idents,
  transf,
  ast,
  sem
]

import codegenlib/java

globalNamespace = "io.github.yu_vitaqua_fer_chronos.nava"

import ./[
  asthelpers,
  utils
]

let file = "/tmp/ee.nim"

file.writeFile("""
proc test*(arg: int) = echo "Hello world!"
""")

var
  cache: IdentCache = newIdentCache()
  config: ConfigRef = newConfigRef()

let path = getCurrentDir() / "Nim" / "lib"

config.libpath = AbsoluteDir(path)
config.searchPaths.add config.libpath
config.projectFull = AbsoluteFile(file)
config.symbols.defineSymbol("nava")
initDefines(config.symbols)

var graph = newModuleGraph(cache, config)

type
  JavaContext = ref object of PPassContext
    graph: ModuleGraph
    module: PSym
    nodes: seq[PNode]
    dedupNodes: seq[PNode]
    depth: int
    seensProcs: HashSet[ItemId]
    javaFiles: Table[string, JavaFile]

proc gen(ctx: JavaContext, n: PNode)

var jvContext: JavaContext

proc passOpen(graph: ModuleGraph, module: PSym,
    idgen: IdGenerator): PPassContext =
  jvContext = JavaContext(graph: graph, module: module)
  return jvContext

proc passNode(p: PPassContext, n: PNode): PNode =
  let ctx = JavaContext(p)
  result = n

  if sfMainModule in ctx.module.flags:
  #if n != nil:
    #var res: string

    #n.treeTraverse(res, level = 0, isLisp = false, indented = true)

    #echo "\n", res

    ctx.javaFiles[ctx.module.getModuleName()] = newJavaFile(ctx.module.getPackageName())

    #ctx.gen n

proc passClose(graph: ModuleGraph, p: PPassContext, n: PNode): PNode =
  discard


## Start code gen
proc genProc(ctx: JavaContext, s: PSym) =
  ctx.depth += 1
  assert s.kind in routineKinds
  # only generate code for the procedure once
  if not ctx.seensProcs.containsOrIncl(s.itemId):
    let body = transformBody(ctx.graph, ctx.idgen, s, useCache)
    gen(ctx, body)
  ctx.depth -= 1

proc genMagic(ctx: JavaContext, m: TMagic, callExpr: PNode): bool =
  ## Returns 'false' if no special handling is used and a default function
  ## call is to be emitted instead
  # implement special handling for calls to magics here...
  result = true

  case m
  else:
    echo "Missing magic: ", m
    result = false

proc genCall(ctx: JavaContext, n: PNode) =
  # generate code for the call:
  # ...
  echo n.kind

proc gen(ctx: JavaContext, n: PNode) =
  ## Generate code for the expression or statement `n`
  case n.kind
  of nkSym:
    let s = n.sym

    case s.kind
    of skProc, skFunc, skIterator, skConverter:
      genProc(ctx, s)

    of skVar:
      case s.astdef.kind
      of nkStrLit..nkTripleStrLit:
        echo "Implementation missing for string def: ", s.astdef.kind

      # TODO: Implement `uint` math, it is fucking hell in Java and the JVM, because it doesn't already exist
      of nkIntLit..nkUInt64Lit:
        echo "Implementation missing for number def: ", s.astdef.kind

      else:
        echo "Implementation missing for variable def: ", s.astdef.kind

    else:
      # handling of other symbol kinds here...
      echo "Implementation missing for: ", s.kind

  of nkCallKinds:
    if n[0].kind == nkSym:
      let s = n[0].sym

      let useNormal = 
        if s.magic != mNone:
          # if ``genMagic`` returns 'false', the procedure is treated as a
          # non-builtin and uses the same code-generator logic as all other
          # procedures 
          not genMagic(ctx, s.magic, n)
        else:
          true

      if useNormal:
        genCall(ctx, n)

    else:
      # indirect call
      genCall(ctx, n)

  of routineDefs, nkTypeSection, nkTypeOfExpr, nkCommentStmt, nkIncludeStmt,
      nkImportStmt, nkImportExceptStmt, nkExportStmt, nkExportExceptStmt,
      nkFromStmt, nkStaticStmt:
    # ignore declarative nodes, e.g. routine definitions, import statments, etc.
    discard

  of nkLiterals:
    if n notin ctx.dedupNodes:
      case n.kind

      else:
        echo "Implementation missing for: ", n.kind

  of nkStmtList: # Go through child nodes
    for i in 0..<n.len:
      gen(ctx, n[i])

  of nkIdentDefs:
    for i in 0..<n.len:
      gen(ctx, n[i])

  of nkVarSection:
    for i in 0..<n.len:
      gen(ctx, n[i])

  of nkBracket:
    for i in 0..<n.len:
      gen(ctx, n[i])

  of nkHiddenStdConv:
    for i in 0..<n.len:
      gen(ctx, n[i])
      echo n[i].kind

  of nkEmpty: # Empty nodes can be safely discarded
    discard

  else:
    # each node kind needs it's own visitor logic, but to help with
    # prototyping, nodes for which none is implemented yet simply visit their
    # children (if any)
    # ``safeLen`` is used because the node might be a leaf node
    echo "Unimplemented node: ", n.kind
    for i in 0..<n.safeLen:
      gen(ctx, n[i])

## End code gen

registerPass(graph, semPass)
registerPass(graph, makePass(passOpen, passNode, passClose))
compileProject(graph)