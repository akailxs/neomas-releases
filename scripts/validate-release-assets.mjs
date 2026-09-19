import { readdir, readFile, stat } from 'node:fs/promises'
import path from 'node:path'

const dir = path.resolve(process.env.RELEASE_ASSETS_DIR || 'release-assets')
const tag = process.env.RELEASE_TAG || process.argv[2] || ''
const match = /^v(\d+\.\d+\.\d+)$/.exec(tag)

if (!match) throw new Error(`RELEASE_TAG doit être de la forme vX.Y.Z (reçu : ${tag || 'vide'})`)
const version = match[1]
const names = (await readdir(dir)).sort()
const files = new Set(names)
const manifests = ['latest-mac.yml', 'latest.yml'].filter((name) => files.has(name))

if (manifests.length === 0) {
  throw new Error('Aucun manifeste latest-mac.yml/latest.yml : refus de publier un feed incomplet')
}

for (const name of names) {
  const fileStat = await stat(path.join(dir, name))
  if (!fileStat.isFile()) throw new Error(`Asset inattendu (pas un fichier) : ${name}`)
  const embedded = name.match(/\d+\.\d+\.\d+/)?.[0]
  if (embedded && embedded !== version) {
    throw new Error(`${name} porte la version ${embedded}, mais la release est ${tag}`)
  }
}

for (const manifest of manifests) {
  const source = await readFile(path.join(dir, manifest), 'utf8')
  const manifestVersion = source.match(/^version:\s*['"]?([^'"\s]+)['"]?/m)?.[1]
  if (manifestVersion !== version) {
    throw new Error(`${manifest} annonce ${manifestVersion || 'aucune version'}, attendu ${version}`)
  }

  const urls = [...source.matchAll(/^\s*-\s+url:\s+(.+?)\s*$/gm)].map((m) => m[1].replace(/^['"]|['"]$/g, ''))
  if (urls.length === 0) throw new Error(`${manifest} ne référence aucun fichier`)
  for (const url of urls) {
    if (url.includes('/') || url.includes('\\')) throw new Error(`${manifest} contient un chemin non local : ${url}`)
    if (!files.has(url)) throw new Error(`${manifest} référence ${url}, absent des assets GitHub`)
    if ((url.endsWith('.zip') || url.endsWith('.exe')) && !files.has(`${url}.blockmap`)) {
      throw new Error(`${url}.blockmap manque : la mise à jour différentielle serait cassée`)
    }
  }
}

if (files.has('latest-mac.yml')) {
  const arm = names.filter((name) => name.endsWith('-arm64.dmg'))
  const intel = names.filter((name) => name.endsWith('-x64.dmg') || name === `Neomas-${version}.dmg`)
  if (arm.length !== 1 || intel.length !== 1) {
    throw new Error(`Release macOS ambiguë : ${arm.length} DMG arm64 et ${intel.length} DMG Intel`)
  }
}

if (files.has('latest.yml')) {
  const installers = names.filter((name) => name.endsWith('.exe'))
  if (installers.length !== 1) throw new Error(`Release Windows ambiguë : ${installers.length} installeur(s) .exe`)
}

console.log(`Assets ${tag} valides : ${names.length} fichier(s), manifestes ${manifests.join(', ')}`)
