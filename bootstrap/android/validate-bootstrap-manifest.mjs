#!/usr/bin/env node

import { readFileSync } from 'node:fs'
import path from 'node:path'

const EXPECTED_LOOPBACK_URL = 'http://127.0.0.1:1234/api/v1'
const EXPECTED_COLLECTION_INPUTS = [
  'collections/kiwix-categories.json',
  'collections/maps.json',
  'collections/wikipedia.json',
]
const ABI_VALUES = new Set(['arm64-v8a', 'armeabi-v7a', 'x86_64'])
const PAYLOAD_KINDS = new Set(['pwa', 'daemon', 'content', 'map', 'index', 'config'])
const RETENTION_VALUES = new Set(['required', 'rebuildable', 'evictable'])
const TOKEN_RE = /^[a-z0-9][a-z0-9-]{0,47}$/
const TAG_RE = /^[a-z0-9][a-z0-9-]{0,31}$/
const PATH_RE = /^[a-z0-9][a-z0-9._/-]{0,119}$/
const SHA256_RE = /^[a-f0-9]{64}$/

function isPlainObject(value) {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value)
}

function pushError(errors, message) {
  errors.push(message)
}

function ensureString(errors, value, label) {
  if (typeof value !== 'string' || value.length === 0) {
    pushError(errors, `${label} must be a non-empty string`)
    return false
  }
  return true
}

function validateToken(errors, value, label) {
  if (!ensureString(errors, value, label)) return false
  if (!TOKEN_RE.test(value)) {
    pushError(errors, `${label} must match ${TOKEN_RE}`)
    return false
  }
  return true
}

function validateTagList(errors, value, label) {
  if (!Array.isArray(value) || value.length === 0) {
    pushError(errors, `${label} must be a non-empty array`)
    return false
  }

  const seen = new Set()
  for (const tag of value) {
    if (typeof tag !== 'string' || !TAG_RE.test(tag)) {
      pushError(errors, `${label} contains invalid tag "${String(tag)}"`)
      continue
    }
    if (seen.has(tag)) {
      pushError(errors, `${label} contains duplicate tag "${tag}"`)
      continue
    }
    seen.add(tag)
  }

  return true
}

function validatePortablePath(errors, value, label) {
  if (!ensureString(errors, value, label)) return false
  if (!PATH_RE.test(value)) {
    pushError(errors, `${label} must be lowercase ASCII and 120 chars or fewer`)
    return false
  }
  if (value.startsWith('/') || value.includes('..') || value.includes('//')) {
    pushError(errors, `${label} must stay inside bundle root`)
    return false
  }
  return true
}

function main() {
  const inputPath = process.argv[2]

  if (!inputPath) {
    console.error('Usage: node bootstrap/android/validate-bootstrap-manifest.mjs <bootstrap.json>')
    process.exit(64)
  }

  let manifest
  try {
    const raw = readFileSync(inputPath, 'utf8')
    manifest = JSON.parse(raw)
  } catch (error) {
    console.error(`Failed to read ${inputPath}: ${error.message}`)
    process.exit(1)
  }

  const errors = []

  if (!isPlainObject(manifest)) {
    pushError(errors, 'Manifest root must be an object')
  }

  if (manifest.schema_version !== '1.0') {
    pushError(errors, 'schema_version must be "1.0"')
  }

  if (!isPlainObject(manifest.bundle)) {
    pushError(errors, 'bundle must be an object')
  } else {
    validateToken(errors, manifest.bundle.id, 'bundle.id')
    ensureString(errors, manifest.bundle.version, 'bundle.version')
    ensureString(errors, manifest.bundle.label, 'bundle.label')
    if (manifest.bundle.format !== 'zip') {
      pushError(errors, 'bundle.format must be "zip"')
    }
  }

  if (!isPlainObject(manifest.compatibility)) {
    pushError(errors, 'compatibility must be an object')
  } else {
    const androidApiMin = manifest.compatibility.android_api_min
    if (!Number.isInteger(androidApiMin) || androidApiMin < 21) {
      pushError(errors, 'compatibility.android_api_min must be an integer >= 21')
    }

    const supportedAbis = manifest.compatibility.supported_abis
    if (!Array.isArray(supportedAbis) || supportedAbis.length === 0) {
      pushError(errors, 'compatibility.supported_abis must be a non-empty array')
    } else {
      const seen = new Set()
      for (const abi of supportedAbis) {
        if (!ABI_VALUES.has(abi)) {
          pushError(errors, `compatibility.supported_abis contains unsupported abi "${String(abi)}"`)
          continue
        }
        if (seen.has(abi)) {
          pushError(errors, `compatibility.supported_abis contains duplicate abi "${abi}"`)
          continue
        }
        seen.add(abi)
      }
    }
  }

  if (!isPlainObject(manifest.defaults)) {
    pushError(errors, 'defaults must be an object')
  } else {
    if (manifest.defaults.seed_network_policy !== 'OFF') {
      pushError(errors, 'defaults.seed_network_policy must stay OFF for bootstrap bundles')
    }
    if (manifest.defaults.oneshot_enabled !== true) {
      pushError(errors, 'defaults.oneshot_enabled must be true')
    }
    validateToken(errors, manifest.defaults.storage_profile, 'defaults.storage_profile')
    if (manifest.defaults.loopback_base_url !== EXPECTED_LOOPBACK_URL) {
      pushError(errors, `defaults.loopback_base_url must be ${EXPECTED_LOOPBACK_URL}`)
    }
  }

  const profileIds = new Set()
  if (!Array.isArray(manifest.storage_profiles) || manifest.storage_profiles.length === 0) {
    pushError(errors, 'storage_profiles must be a non-empty array')
  } else {
    for (const [index, profile] of manifest.storage_profiles.entries()) {
      const label = `storage_profiles[${index}]`
      if (!isPlainObject(profile)) {
        pushError(errors, `${label} must be an object`)
        continue
      }

      if (validateToken(errors, profile.id, `${label}.id`)) {
        if (profileIds.has(profile.id)) {
          pushError(errors, `${label}.id "${profile.id}" is duplicated`)
        }
        profileIds.add(profile.id)
      }

      ensureString(errors, profile.label, `${label}.label`)

      if (!Number.isInteger(profile.max_persistent_mb) || profile.max_persistent_mb < 64) {
        pushError(errors, `${label}.max_persistent_mb must be an integer >= 64`)
      }

      const keepOk = validateTagList(errors, profile.keep_tags, `${label}.keep_tags`)
      let dropTags = []
      if (profile.drop_tags !== undefined) {
        validateTagList(errors, profile.drop_tags, `${label}.drop_tags`)
        dropTags = Array.isArray(profile.drop_tags) ? profile.drop_tags : []
      }

      if (keepOk) {
        const keepTags = new Set(profile.keep_tags)
        for (const dropTag of dropTags) {
          if (keepTags.has(dropTag)) {
            pushError(errors, `${label} cannot keep and drop "${dropTag}" at the same time`)
          }
        }
      }
    }
  }

  if (manifest.defaults?.storage_profile && !profileIds.has(manifest.defaults.storage_profile)) {
    pushError(errors, `defaults.storage_profile "${manifest.defaults.storage_profile}" is not defined`)
  }

  const payloadIds = new Map()
  if (!Array.isArray(manifest.payloads) || manifest.payloads.length === 0) {
    pushError(errors, 'payloads must be a non-empty array')
  } else {
    for (const [index, payload] of manifest.payloads.entries()) {
      const label = `payloads[${index}]`
      if (!isPlainObject(payload)) {
        pushError(errors, `${label} must be an object`)
        continue
      }

      if (validateToken(errors, payload.id, `${label}.id`)) {
        if (payloadIds.has(payload.id)) {
          pushError(errors, `${label}.id "${payload.id}" is duplicated`)
        }
        payloadIds.set(payload.id, payload)
      }

      if (!PAYLOAD_KINDS.has(payload.kind)) {
        pushError(errors, `${label}.kind "${String(payload.kind)}" is unsupported`)
      }

      if (validatePortablePath(errors, payload.path, `${label}.path`) && !payload.path.startsWith('payloads/')) {
        pushError(errors, `${label}.path must live under payloads/`)
      }

      if (payload.kind === 'daemon') {
        if (!ABI_VALUES.has(payload.abi)) {
          pushError(errors, `${label}.abi must be a concrete daemon ABI`)
        }
      } else if (payload.abi !== 'any') {
        pushError(errors, `${label}.abi must be "any" for non-daemon payloads`)
      }

      if (typeof payload.required !== 'boolean') {
        pushError(errors, `${label}.required must be boolean`)
      }

      if (!RETENTION_VALUES.has(payload.retention)) {
        pushError(errors, `${label}.retention "${String(payload.retention)}" is unsupported`)
      }
      if (payload.required === true && payload.retention !== 'required') {
        pushError(errors, `${label} is required but retention is not "required"`)
      }

      validateTagList(errors, payload.install_tags, `${label}.install_tags`)

      if (!Number.isInteger(payload.size_bytes) || payload.size_bytes < 1) {
        pushError(errors, `${label}.size_bytes must be a positive integer`)
      }

      if (!ensureString(errors, payload.sha256, `${label}.sha256`) || !SHA256_RE.test(payload.sha256)) {
        pushError(errors, `${label}.sha256 must be 64 lowercase hex characters`)
      }
    }
  }

  if (!isPlainObject(manifest.runtime)) {
    pushError(errors, 'runtime must be an object')
  } else {
    const pwaPayload = payloadIds.get(manifest.runtime.pwa_payload_id)
    if (!pwaPayload) {
      pushError(errors, 'runtime.pwa_payload_id must reference an existing payload')
    } else if (pwaPayload.kind !== 'pwa') {
      pushError(errors, 'runtime.pwa_payload_id must reference a payload with kind "pwa"')
    }

    const daemonRefs = new Map()
    if (!Array.isArray(manifest.runtime.daemon_payloads) || manifest.runtime.daemon_payloads.length === 0) {
      pushError(errors, 'runtime.daemon_payloads must be a non-empty array')
    } else {
      for (const [index, ref] of manifest.runtime.daemon_payloads.entries()) {
        const label = `runtime.daemon_payloads[${index}]`
        if (!isPlainObject(ref)) {
          pushError(errors, `${label} must be an object`)
          continue
        }
        if (!ABI_VALUES.has(ref.abi)) {
          pushError(errors, `${label}.abi "${String(ref.abi)}" is unsupported`)
          continue
        }
        if (daemonRefs.has(ref.abi)) {
          pushError(errors, `${label}.abi "${ref.abi}" is duplicated`)
          continue
        }
        daemonRefs.set(ref.abi, ref.payload_id)

        const payload = payloadIds.get(ref.payload_id)
        if (!payload) {
          pushError(errors, `${label}.payload_id "${String(ref.payload_id)}" does not exist`)
          continue
        }
        if (payload.kind !== 'daemon') {
          pushError(errors, `${label}.payload_id must reference a daemon payload`)
        }
        if (payload.abi !== ref.abi) {
          pushError(errors, `${label}.payload_id abi mismatch: expected ${ref.abi}, found ${payload.abi}`)
        }
      }

      for (const abi of manifest.compatibility?.supported_abis || []) {
        if (!daemonRefs.has(abi)) {
          pushError(errors, `runtime.daemon_payloads does not cover supported abi "${abi}"`)
        }
      }
    }
  }

  const upstreamPaths = new Set()
  if (!Array.isArray(manifest.upstream_inputs) || manifest.upstream_inputs.length === 0) {
    pushError(errors, 'upstream_inputs must be a non-empty array')
  } else {
    for (const [index, entry] of manifest.upstream_inputs.entries()) {
      const label = `upstream_inputs[${index}]`
      if (!isPlainObject(entry)) {
        pushError(errors, `${label} must be an object`)
        continue
      }
      if (entry.kind !== 'collections_manifest') {
        pushError(errors, `${label}.kind must be "collections_manifest"`)
      }
      if (validatePortablePath(errors, entry.path, `${label}.path`)) {
        if (!entry.path.startsWith('collections/')) {
          pushError(errors, `${label}.path must live under collections/`)
        }
        upstreamPaths.add(entry.path)
      }
      if (entry.required !== true) {
        pushError(errors, `${label}.required must be true for canonical collection inputs`)
      }
    }
  }

  for (const expectedPath of EXPECTED_COLLECTION_INPUTS) {
    if (!upstreamPaths.has(expectedPath)) {
      pushError(errors, `Missing canonical upstream input "${expectedPath}"`)
    }
  }

  if (errors.length > 0) {
    console.error(`Manifest validation failed for ${path.resolve(inputPath)}`)
    for (const error of errors) {
      console.error(`- ${error}`)
    }
    process.exit(1)
  }

  console.log(`Manifest valid: ${path.resolve(inputPath)}`)
  console.log(`- profiles: ${manifest.storage_profiles.length}`)
  console.log(`- payloads: ${manifest.payloads.length}`)
  console.log(`- canonical upstream manifests: ${manifest.upstream_inputs.length}`)
}

main()
