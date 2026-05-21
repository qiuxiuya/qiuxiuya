function operator(proxies, targetPlatform, context) {
  const platform = String(targetPlatform)
  const supportAnyTLS = ['Surge', 'ClashMeta', 'Sing-box','JSON'].includes(platform)

  const anytlsNames = new Set(
    proxies
      .filter(p => p.type === 'anytls')
      .map(p => p.name)
  )

  if (supportAnyTLS) {
    return proxies.filter(p => {
      if (anytlsNames.has(p.name)) {
        return p.type === 'anytls'
      }
      return true
    })
  } else {
    return proxies.filter(p => p.type !== 'anytls')
  }
}
