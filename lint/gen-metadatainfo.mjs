#!/usr/bin/env node
// R-DOC-6 元数据侧车生成器：为每篇 .md 生成 <name>.md.metadatainfo（缺则补，默认不覆盖）。
// 用法：node lint/gen-metadatainfo.mjs <repo-root> [--force]
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.argv[2] || process.cwd())
const force = process.argv.includes('--force')
const SKIP_DIRS = new Set(['.git', 'node_modules', '.playwright-mcp', 'shots'])

const SPECIAL = {
  'principles.md': { tags: [['principles', 'domain'], ['constitution', 'domain']], importance: 100 },
  'goal.md': { tags: [['goal', 'domain']], importance: 100 },
  'desc.md': { tags: [['desc', 'domain']], importance: 90 },
  'architecture.md': { tags: [['architecture', 'domain']], importance: 90 },
  'open-questions.md': { tags: [['open-questions', 'doc']], importance: 70 },
  'README.md': { tags: [['index', 'doc']], importance: 60 },

  'rule/rule.md': { tags: [['rule', 'doc'], ['index', 'doc']], importance: 98 },
  'rule/rule_doc.md': { tags: [['doc', 'domain'], ['rule', 'doc']], importance: 95 },
  'rule/rule_eng.md': { tags: [['engineering', 'domain'], ['rule', 'doc']], importance: 95 },
  'rule/rule_ux.md': { tags: [['ux', 'domain'], ['console', 'surface'], ['rule', 'doc']], importance: 98 },
  'rule/rule_ctx.md': { tags: [['context', 'domain'], ['rule', 'doc']], importance: 95 },
  'rule/rule_pub.md': { tags: [['public-repo', 'domain'], ['rule', 'doc']], importance: 90 },
  'rule/rule_type.md': { tags: [['rule', 'doc'], ['checker', 'mech']], importance: 90 },

  'concepts/README.md': { tags: [['index', 'doc'], ['concept', 'doc']], importance: 80 },
  'concepts/attention.md': { tags: [['attention', 'domain'], ['console', 'surface'], ['report', 'surface']], importance: 95 },
  'acceptance/README.md': { tags: [['acceptance', 'doc'], ['index', 'doc']], importance: 60 },
  'acceptance/console/console-ui.md': { tags: [['console', 'surface'], ['ux', 'domain'], ['acceptance', 'doc']], importance: 95 },
  'runtime/console-adoption.md': { tags: [['console', 'surface'], ['adoption', 'lifecycle'], ['runtime', 'doc']], importance: 85 },
  'runtime/context-rag.md': { tags: [['context', 'domain'], ['runtime', 'doc']], importance: 85 },
  'runtime/cored-bridge.md': { tags: [['bridge', 'mech'], ['runtime', 'doc']], importance: 80 },
  'runtime/acceptance.md': { tags: [['acceptance', 'doc'], ['runtime', 'doc']], importance: 70 },
  'feasibility.md': { tags: [['feasibility', 'doc']], importance: 70 }
}

const FOLDER = [
  ['concepts/', 82, 'domain', 'concept'],
  ['rule/', 95, 'doc', 'rule'],
  ['requirements/', 30, 'doc', 'requirement'],
  ['doctypes/', 80, 'domain', 'doctype'],
  ['systems/', 75, 'domain', 'system'],
  ['runtime/', 75, 'mech', 'runtime'],
  ['acceptance/', 70, 'doc', 'acceptance'],
  ['mvp/', 50, 'doc', 'mvp'],
  ['impl/', 60, 'mech', 'impl'],
  ['examples/', 40, 'doc', 'example']
]

function walk(dir, out = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ent.name.startsWith('.') && ent.name !== '.') continue
    if (SKIP_DIRS.has(ent.name) || ent.name === 'friddle_decision.md') continue
    const p = path.join(dir, ent.name)
    if (ent.isDirectory()) walk(p, out)
    else if (ent.isFile() && ent.name.endsWith('.md')) out.push(p)
  }
  return out
}

function rel(p) { return path.relative(root, p).split(path.sep).join('/') }

function metaFor(relPath) {
  const base = path.basename(relPath, '.md')
  const special = SPECIAL[relPath]
  if (special) return special
  const stem = base.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fa5._-]+/g, '-').replace(/^-+|-+$/g, '') || 'doc'
  let importance = 60, tagType = 'doc', folderTag = null
  for (const [prefix, imp, type, tag] of FOLDER) {
    if (relPath.startsWith(prefix)) { importance = imp; tagType = type; folderTag = tag; break }
  }
  if (base === 'README') return { tags: [[stem, 'doc'], ['index', 'doc']], importance: Math.min(importance, 60) }
  const tags = [[stem, tagType]]
  if (folderTag && folderTag !== stem) tags.push([folderTag, 'doc'])
  return { tags, importance }
}

function render(meta) {
  const lines = ['# 元数据侧车（R-DOC-6）：正文以同名 .md 为准；导出/GitHub 镜像保留', 'tags:']
  for (const [tag, type] of meta.tags) lines.push(`  - {tag: ${tag}, tag_type: ${type}}`)
  lines.push(`importance: ${meta.importance}`, '')
  return lines.join('\n')
}

const files = walk(root)
let created = 0, kept = 0
for (const file of files) {
  const sidecar = `${file}.metadatainfo`
  if (fs.existsSync(sidecar) && !force) { kept++; continue }
  fs.writeFileSync(sidecar, render(metaFor(rel(file))))
  created++
}
console.log(`metadatainfo: created=${created} kept=${kept} total_md=${files.length} root=${root}`)
