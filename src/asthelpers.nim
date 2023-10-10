import std/[
  strformat
]

import Nim/compiler/[
  ast
]

const collapseSymChoice = not defined(nimLegacyMacrosCollapseSymChoice)

proc treeTraverse*(n: PNode, res: var string, level = 0, isLisp = false, indented = false) =
  if level > 0:
    if indented:
      res.add("\n")
      for i in 0 .. level-1:
        if isLisp:
          res.add(" ")          # dumpLisp indentation
        else:
          res.add("  ")         # dumpTree indentation
    else:
      res.add(" ")

  if isLisp:
    res.add("(")
  res.add(($n.kind).substr(2))

  case n.kind
  of nkEmpty:
    discard # same as nil node in this representation
  of nkCharLit..nkInt64Lit:
    res.add &" {n.intVal}"
  of nkUIntLit..nkUInt64Lit:
    res.add &" {cast[uint64](n.intVal)}"
  of nkFloatLit..nkFloat64Lit:
    res.add &" {n.floatVal}"
  of nkStrLit..nkTripleStrLit:
    res.add &" \"{n.strVal}\""
  of nkCommentStmt:
    res.add &" \"{n.comment}\""
  of nkSym:
    res.add &" `{n.sym.name.s}`"
  of nkIdent:
    res.add &" `{n.ident.s}`"
  of nkNone:
    assert false
  elif n.kind in {nkOpenSymChoice, nkClosedSymChoice} and collapseSymChoice:
    res.add &" {n.len}"
    if n.len > 0:
      var allSameSymName = true
      for i in 0..<n.len:
        if n[i].kind != nkSym or not (n[i] == n[0]):
          allSameSymName = false
          break
      if allSameSymName:
        res.add &" {n[0].sym.name.s}"
      else:
        for j in 0 ..< n.len:
          n[j].treeTraverse(res, level+1, isLisp, indented)
  else:
    for j in 0 ..< n.len:
      n[j].treeTraverse(res, level+1, isLisp, indented)

  if isLisp:
    res.add(")")

